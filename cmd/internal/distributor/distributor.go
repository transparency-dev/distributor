// Copyright 2023 Google LLC. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package distributor contains a DB-backed object that persists witnessed
// checkpoints of verifiable logs and allows them to be queried to allow
// efficient lookup by-witness, and by number of signatures.
package distributor

import (
	"bytes"
	"context"
	"database/sql"
	"fmt"
	"sort"

	"github.com/golang/glog"
	"github.com/transparency-dev/distributor/internal/checkpoints"
	"github.com/transparency-dev/formats/log"
	"golang.org/x/mod/sumdb/note"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// maxSigs is the maximum number of sigs that can be requested.
const maxSigs = 100

// LogInfo contains the information that the distributor needs to know about
// a log, other than its ID.
type LogInfo struct {
	Origin   string
	Verifier note.Verifier
}

// NewDistributor returns a distributor that will accept checkpoints from
// the given witnesses, for the given logs, and persist its state in the
// database provided. Callers must call Init() on the returned distributor.
// `ws` is a map from witness ID (verifier key name) to the note verifier.
// `ls` is a map from log ID (github.com/transparency-dev/formats/log.ID) to log info.
func NewDistributor(ws map[string]note.Verifier, ls map[string]LogInfo, db *sql.DB) (*Distributor, error) {
	d := &Distributor{
		ws: ws,
		ls: ls,
		db: db,
	}
	return d, d.init()
}

// Distributor persists witnessed checkpoints and allows querying of them.
type Distributor struct {
	ws map[string]note.Verifier
	ls map[string]LogInfo
	db *sql.DB
}

// GetLogs returns a list of all log IDs the distributor is aware of, sorted
// by the ID.
func (d *Distributor) GetLogs(ctx context.Context) ([]string, error) {
	r := make([]string, 0, len(d.ls))
	for k := range d.ls {
		r = append(r, k)
	}
	sort.Strings(r)
	return r, nil
}

// GetCheckpointN gets the largest checkpoint for a given log that has at least `n` signatures.
func (d *Distributor) GetCheckpointN(ctx context.Context, logID string, n uint32) ([]byte, error) {
	if n == 0 || n > maxSigs {
		return nil, status.Errorf(codes.InvalidArgument, "invalid N %d", n)
	}
	if _, ok := d.ls[logID]; !ok {
		return nil, status.Errorf(codes.InvalidArgument, "unknown log ID %q", logID)
	}

	tx, err := d.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: true})
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %v", err)
	}
	row := tx.QueryRowContext(ctx, "SELECT chkpt FROM merged_checkpoints WHERE logID = ? AND sigCount = ?", logID, n)
	if row.Err() != nil {
		return nil, fmt.Errorf("QueryRowContext(): %v", err)
	}
	var cp []byte
	if err := row.Scan(&cp); err != nil {
		if err == sql.ErrNoRows {
			return nil, status.Errorf(codes.NotFound, "no checkpoint with %d signatures found", n)
		}
		return nil, fmt.Errorf("Scan(): %v", err)
	}
	return cp, nil
}

// GetCheckpointWitness gets the largest checkpoint for the log that was witnessed by the given witness.
func (d *Distributor) GetCheckpointWitness(ctx context.Context, logID, witID string) ([]byte, error) {
	tx, err := d.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: true})
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %v", err)
	}
	return getLatestCheckpoint(ctx, tx, logID, witID)
}

// Distribute adds a new witnessed checkpoint to be distributed. This checkpoint must be signed
// by both the log and the witness specified, and be larger than any previous checkpoint distributed
// for this pair.
func (d *Distributor) Distribute(ctx context.Context, logID, witID string, nextRaw []byte) error {
	l, ok := d.ls[logID]
	if !ok {
		return fmt.Errorf("unknown log ID %q", logID)
	}
	wv, ok := d.ws[witID]
	if !ok {
		return fmt.Errorf("unknown witness ID %q", witID)
	}
	newCP, _, n, err := log.ParseCheckpoint(nextRaw, l.Origin, l.Verifier, wv)
	if err != nil {
		return fmt.Errorf("failed to parse checkpoint: %v", err)
	}
	if len(n.Sigs) != 2 {
		return fmt.Errorf("failed to verify log and witness signatures; only verified: %v", n.Sigs)
	}

	// This is a valid checkpoint for this log for this witness
	// Now find the previous checkpoint if one exists.

	tx, err := d.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: false})
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %v", err)
	}
	oldBs, err := getLatestCheckpoint(ctx, tx, logID, witID)
	if err != nil {
		if status.Code(err) != codes.NotFound {
			return fmt.Errorf("failed to query for latest checkpoint: %v", err)
		}
	}
	if oldBs != nil {
		// To replace a previous checkpoint from the same witness, check that the new one is fresher
		oldCP, _, _, err := log.ParseCheckpoint(oldBs, l.Origin, l.Verifier, wv)
		if err != nil {
			// This really shouldn't ever happen unless the DB is corrupted or the config
			// for the log or verifier has changed.
			return fmt.Errorf("failed to parse checkpoint: %v", err)
		}
		if newCP.Size < oldCP.Size {
			return fmt.Errorf("checkpoint for log %q and witness %q is for size %d, cannot update to size %d", logID, witID, oldCP.Size, newCP.Size)
		}
		if newCP.Size == oldCP.Size {
			if !bytes.Equal(newCP.Hash, oldCP.Hash) {
				reportInconsistency(oldBs, nextRaw)
				return fmt.Errorf("old checkpoint for tree size %d had hash %x but new one has %x", newCP.Size, oldCP.Hash, newCP.Hash)
			}
			// Nothing to do; checkpoint is equivalent to the old one so avoid DB writes.
			return nil
		}
	}

	// At this point we know that we have a valid checkpoint that is fresher than any previous version for
	// this witness. We should now store this, and then attempt to merge with other checkpoints for the same
	// log size to create the checkpoint.N files.

	if _, err := tx.ExecContext(ctx, `REPLACE INTO checkpoints_by_witness (logID, witID, treeSize, chkpt) VALUES (?, ?, ?, ?)`, logID, witID, newCP.Size, nextRaw); err != nil {
		return fmt.Errorf("ExecContext(): %v", err)
	}

	// Calculate new checkpoint.N given this new checkpoint.
	rows, err := tx.QueryContext(ctx, "SELECT witID, chkpt FROM checkpoints_by_witness WHERE logID = ? AND treeSize = ? ORDER BY witID ASC", logID, newCP.Size)
	if err != nil {
		return fmt.Errorf("QueryContext(): %v", err)
	}
	defer func() {
		if err := rows.Close(); err != nil {
			glog.Errorf("rows.Close(): %v", err)
		}
	}()

	var witnesses []note.Verifier
	var allCheckpoints [][]byte
	for rows.Next() {
		var witID string
		var cp []byte
		if err := rows.Scan(&witID, &cp); err != nil {
			return fmt.Errorf("failed to scan rows: %v", err)
		}
		allCheckpoints = append(allCheckpoints, cp)
		witnesses = append(witnesses, d.ws[witID])
	}

	if err := rows.Err(); err != nil {
		return fmt.Errorf("rows.Err(): %v", err)
	}

	sigCount := len(witnesses)
	row := tx.QueryRowContext(ctx, "SELECT treeSize FROM merged_checkpoints WHERE logID = ? AND sigCount = ?", logID, sigCount)
	if row.Err() != nil {
		return fmt.Errorf("QueryRowContext(): %v", err)
	}
	var lastTreeSize uint64
	if err := row.Scan(&lastTreeSize); err != nil {
		if err != sql.ErrNoRows {
			return fmt.Errorf("Scan(): %v", err)
		}
		// If there are no rows then that's fine, we'll allow lastTreeSize to stay at 0
	}
	if newCP.Size > lastTreeSize {
		// If the new checkpoint is for a tree larger than the current checkpoint.N for this log, then
		// we have the option of creating a new checkpoint.N for the larger tree size.
		mergedCP, err := checkpoints.Combine(allCheckpoints, l.Verifier, note.VerifierList(witnesses...))
		if err != nil {
			// This could happen because the log has variable info, such as a timestamp.
			// Don't treat this as a critical error or the distributor can't accept the new checkpoint.
			glog.Warning("Failed to combine %d checkpoints: %v", sigCount, err)
		} else {
			_, err = tx.ExecContext(ctx, `REPLACE INTO merged_checkpoints (logID, sigCount, treeSize, chkpt) VALUES (?, ?, ?, ?)`, logID, sigCount, newCP.Size, mergedCP)
			if err != nil {
				return fmt.Errorf("Failed to update checkpoints.%d: %v", sigCount, err)
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return err
	}
	return nil
}

// init ensures that the database is in good order. This must be called before
// any other method on this object. It is safe to call on subsequent runs of
// the application as it is idempotent.
func (d *Distributor) init() error {
	if _, err := d.db.Exec(`CREATE TABLE IF NOT EXISTS checkpoints_by_witness (
		logID VARCHAR(200),
		witID VARCHAR(200),
		treeSize INTEGER,
		chkpt BLOB,
		PRIMARY KEY (logID, witID)
		)`); err != nil {
		return err
	}
	if _, err := d.db.Exec(`CREATE TABLE IF NOT EXISTS merged_checkpoints (
		logID VARCHAR(200),
		sigCount INTEGER,
		treeSize INTEGER,
		chkpt BLOB,
		PRIMARY KEY (logID, sigCount)
		)`); err != nil {
		return err
	}
	return nil
}

// getLatestCheckpoint returns the latest checkpoint for the given log and witness pair.
// If no checkpoint is found then an error with status `codes.NotFound` will be returned,
// which allows callers to handle this case separately if needed.
func getLatestCheckpoint(ctx context.Context, tx *sql.Tx, logID, witID string) ([]byte, error) {
	row := tx.QueryRowContext(ctx, "SELECT chkpt FROM checkpoints_by_witness WHERE logID = ? AND witID = ?", logID, witID)
	if err := row.Err(); err != nil {
		return nil, err
	}
	var chkpt []byte
	if err := row.Scan(&chkpt); err != nil {
		if err == sql.ErrNoRows {
			return nil, status.Errorf(codes.NotFound, "no checkpoint for log %q from witness %q", logID, witID)
		}
		return nil, err
	}
	return chkpt, nil
}

// reportInconsistency makes a note when two checkpoints are found for the same
// log tree size, but with different hashes.
// For now, this simply logs an error, but this could be upgraded to write to a
// new DB table containing this kind of evidence. Care needs to be taken if this
// approach is followed to ensure that the DB size stays limited, i.e. don't allow
// the same/similar inconsistencies to be written indefinitely.
func reportInconsistency(oldCP, newCP []byte) {
	glog.Errorf("Found inconsistent checkpoints:\n%v\n\n%v", oldCP, newCP)
}
