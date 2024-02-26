FROM golang:1.22.0-alpine3.19@sha256:3325c5593767d8f1fd580e224707ca5e847a1679470a027aaa3c71711ce16613 AS builder

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
