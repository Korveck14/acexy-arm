# syntax=docker/dockerfile:1

# Build the application from source
FROM --platform=$BUILDPLATFORM golang:1.24.2-alpine AS build-stage
ARG TARGETOS
ARG TARGETARCH

# Install build dependencies
RUN apk add --no-cache git

WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker caching
COPY --link acexy/go.mod acexy/go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY --link acexy/ ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /acexy

# Create a minimal image
FROM alpine:3.21.3 AS final-stage

# Copy the binary from the build stage
COPY --from=build-stage /acexy /acexy

# Set entrypoint and default command
ENTRYPOINT ["/acexy"]
CMD ["--help"]
