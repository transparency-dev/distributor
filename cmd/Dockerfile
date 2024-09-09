FROM golang:1.23.1-alpine3.19@sha256:e0ea2a119ae0939a6d449ea18b2b1ba30b44986ec48dbb88f3a93371b4bf8750 AS builder

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
FROM alpine:3.20.3@sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d

COPY --from=builder /build/bin/distributor /bin/distributor
ENTRYPOINT ["/bin/distributor"]
