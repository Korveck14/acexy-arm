# syntax=docker/dockerfile:1

# Build the application from source
FROM golang:1.22 AS build-stage

WORKDIR /app
COPY --link acexy/ ./

RUN go mod download

# Optimize the binary size by stripping debug info
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /acexy

# Create a minimal image
FROM alpine:latest AS final-stage

# Install curl for healthcheck before copying files (better layer caching)
RUN apk update && apk upgrade --no-cache && apk add --no-cache curl

# Copy entrypoint script and binary
COPY --link bin/entrypoint /bin/entrypoint
COPY --from=build-stage /acexy /acexy

# Expose the application port
EXPOSE 8080

# Set environment variables
ENV EXTRA_FLAGS="--cache-dir /tmp --cache-limit 2 --cache-auto 1 --log-stderr --log-stderr-level error"
ENV ACEXY_LISTEN_ADDR=":8080"

# Healthcheck against the HTTP status endpoint
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -sf "http://localhost${ACEXY_LISTEN_ADDR}/ace/status" || exit 1

# Set entrypoint
ENTRYPOINT [ "/bin/entrypoint" ]
