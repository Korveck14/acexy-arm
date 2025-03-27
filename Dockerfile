# syntax=docker/dockerfile:1

# Build the application from source
FROM golang:alpine AS build-stage

WORKDIR /app
COPY --link acexy/ ./

RUN rm -f go.mod go.sum && \
    go mod init javinator9889/acexy && \
    go mod tidy && \
    go mod download

# Install UPX
RUN apk update && apk add --no-cache upx

# Optimize the binary size by stripping debug info
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -buildvcs=false -ldflags="-s -w" -o /acexy && \
    upx --best /acexy

# Create a minimal image
FROM alpine:latest AS final-stage

# Upgrade image packages
RUN apk update && apk upgrade --no-cache && apk add --no-cache tzdata

# Copy entrypoint script and binary
COPY --link bin/entrypoint /bin/entrypoint
COPY --from=build-stage /acexy /acexy

# Expose the application port
EXPOSE 8080

# Set environment variables
ENV EXTRA_FLAGS="--cache-dir /tmp --cache-limit 2 --cache-auto 1 --log-stderr --log-stderr-level error"
ENV ACEXY_LISTEN_ADDR=":8080"

# Set entrypoint
ENTRYPOINT [ "/bin/entrypoint" ]
