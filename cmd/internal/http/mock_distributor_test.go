// Code generated by MockGen. DO NOT EDIT.
// Source: github.com/transparency-dev/distributor/cmd/internal/http (interfaces: Distributor)

package http_test

import (
	context "context"
	reflect "reflect"

	gomock "github.com/golang/mock/gomock"
)

// MockDistributor is a mock of Distributor interface.
type MockDistributor struct {
	ctrl     *gomock.Controller
	recorder *MockDistributorMockRecorder
}

// MockDistributorMockRecorder is the mock recorder for MockDistributor.
type MockDistributorMockRecorder struct {
	mock *MockDistributor
}

// NewMockDistributor creates a new mock instance.
func NewMockDistributor(ctrl *gomock.Controller) *MockDistributor {
	mock := &MockDistributor{ctrl: ctrl}
	mock.recorder = &MockDistributorMockRecorder{mock}
	return mock
}

// EXPECT returns an object that allows the caller to indicate expected use.
func (m *MockDistributor) EXPECT() *MockDistributorMockRecorder {
	return m.recorder
}

// Distribute mocks base method.
func (m *MockDistributor) Distribute(arg0 context.Context, arg1, arg2 string, arg3 []byte) error {
	m.ctrl.T.Helper()
	ret := m.ctrl.Call(m, "Distribute", arg0, arg1, arg2, arg3)
	ret0, _ := ret[0].(error)
	return ret0
}

// Distribute indicates an expected call of Distribute.
func (mr *MockDistributorMockRecorder) Distribute(arg0, arg1, arg2, arg3 interface{}) *gomock.Call {
	mr.mock.ctrl.T.Helper()
	return mr.mock.ctrl.RecordCallWithMethodType(mr.mock, "Distribute", reflect.TypeOf((*MockDistributor)(nil).Distribute), arg0, arg1, arg2, arg3)
}

// GetCheckpointN mocks base method.
func (m *MockDistributor) GetCheckpointN(arg0 context.Context, arg1 string, arg2 uint32) ([]byte, error) {
	m.ctrl.T.Helper()
	ret := m.ctrl.Call(m, "GetCheckpointN", arg0, arg1, arg2)
	ret0, _ := ret[0].([]byte)
	ret1, _ := ret[1].(error)
	return ret0, ret1
}

// GetCheckpointN indicates an expected call of GetCheckpointN.
func (mr *MockDistributorMockRecorder) GetCheckpointN(arg0, arg1, arg2 interface{}) *gomock.Call {
	mr.mock.ctrl.T.Helper()
	return mr.mock.ctrl.RecordCallWithMethodType(mr.mock, "GetCheckpointN", reflect.TypeOf((*MockDistributor)(nil).GetCheckpointN), arg0, arg1, arg2)
}

// GetCheckpointWitness mocks base method.
func (m *MockDistributor) GetCheckpointWitness(arg0 context.Context, arg1, arg2 string) ([]byte, error) {
	m.ctrl.T.Helper()
	ret := m.ctrl.Call(m, "GetCheckpointWitness", arg0, arg1, arg2)
	ret0, _ := ret[0].([]byte)
	ret1, _ := ret[1].(error)
	return ret0, ret1
}

// GetCheckpointWitness indicates an expected call of GetCheckpointWitness.
func (mr *MockDistributorMockRecorder) GetCheckpointWitness(arg0, arg1, arg2 interface{}) *gomock.Call {
	mr.mock.ctrl.T.Helper()
	return mr.mock.ctrl.RecordCallWithMethodType(mr.mock, "GetCheckpointWitness", reflect.TypeOf((*MockDistributor)(nil).GetCheckpointWitness), arg0, arg1, arg2)
}

// GetLogs mocks base method.
func (m *MockDistributor) GetLogs(arg0 context.Context) ([]string, error) {
	m.ctrl.T.Helper()
	ret := m.ctrl.Call(m, "GetLogs", arg0)
	ret0, _ := ret[0].([]string)
	ret1, _ := ret[1].(error)
	return ret0, ret1
}

// GetLogs indicates an expected call of GetLogs.
func (mr *MockDistributorMockRecorder) GetLogs(arg0 interface{}) *gomock.Call {
	mr.mock.ctrl.T.Helper()
	return mr.mock.ctrl.RecordCallWithMethodType(mr.mock, "GetLogs", reflect.TypeOf((*MockDistributor)(nil).GetLogs), arg0)
}

// GetWitnesses mocks base method.
func (m *MockDistributor) GetWitnesses(arg0 context.Context) ([]string, error) {
	m.ctrl.T.Helper()
	ret := m.ctrl.Call(m, "GetWitnesses", arg0)
	ret0, _ := ret[0].([]string)
	ret1, _ := ret[1].(error)
	return ret0, ret1
}

// GetWitnesses indicates an expected call of GetWitnesses.
func (mr *MockDistributorMockRecorder) GetWitnesses(arg0 interface{}) *gomock.Call {
	mr.mock.ctrl.T.Helper()
	return mr.mock.ctrl.RecordCallWithMethodType(mr.mock, "GetWitnesses", reflect.TypeOf((*MockDistributor)(nil).GetWitnesses), arg0)
}
