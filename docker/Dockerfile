FROM golang:1.24-alpine AS builder
RUN apk add --no-cache git
WORKDIR /build
RUN git clone --depth=1 https://github.com/FreifunkBremen/yanic.git .
RUN go build -o yanic .

FROM alpine:3.19
RUN apk add --no-cache ca-certificates python3
WORKDIR /app
COPY --from=builder /build/yanic .
RUN mkdir -p /data
VOLUME ["/data"]
ENTRYPOINT ["./yanic", "serve", "--config", "/app/yanic.toml"]
