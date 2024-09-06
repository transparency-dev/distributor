FROM golang:1.23.1-alpine3.19@sha256:90a66221a80ac09c0b48d2b2cdc6b03320ccf665dd1e8939d2a839a9220c4f9e AS builder

ARG GOFLAGS="-trimpath -buildvcs=false -buildmode=exe"
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
FROM alpine:3.20.2@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5

COPY --from=builder /build/bin/distributor /bin/distributor
ENTRYPOINT ["/bin/distributor"]
