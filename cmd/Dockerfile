FROM golang:1.22.3-alpine3.19@sha256:282ddcdde8fea3bceb235a539d7a2fee2f52559c5319c42e577df4bcae2c2f39 AS builder

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
FROM alpine:3.19.1@sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b

COPY --from=builder /build/bin/distributor /bin/distributor
ENTRYPOINT ["/bin/distributor"]
