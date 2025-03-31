# syntax=docker/dockerfile:1

# Build the application from source
FROM --platform=$BUILDPLATFORM golang:latest AS build-stage
ARG  TARGETOS
ARG  TARGETARCH

WORKDIR /app
COPY --link acexy/ ./

RUN rm -f go.mod go.sum && \
    go mod init javinator9889/acexy && \
    go mod tidy && \
    go mod download

# Optimize the binary size by stripping debug info
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /acexy

# Create a minimal image
FROM alpine:latest AS final-stage

# Upgrade image packages
RUN apk update && apk upgrade --no-cache && apk add --no-cache tini tzdata

# Copy binary
COPY --from=build-stage /acexy /acexy

# Expose the application port
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/acexy"]
