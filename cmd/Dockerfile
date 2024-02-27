FROM golang:1.22.0-alpine3.19@sha256:8e96e6cff6a388c2f70f5f662b64120941fcd7d4b89d62fec87520323a316bd9 AS builder

ARG GOFLAGS=""
ENV GOFLAGS=$GOFLAGS

# Move to working directory /build
WORKDIR /build

# Copy and download dependency using go mod
COPY go.mod .
COPY go.sum .
RUN go mod download

# Copy the code into the container
COPY . .

# Build the application
RUN go build -o bin/distributor ./cmd

# Build release image
FROM alpine:3.17.3

COPY --from=builder /build/bin/distributor /bin/distributor
ENTRYPOINT ["/bin/distributor"]
