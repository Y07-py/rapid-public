FROM rust:1.91-bookworm AS builder
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY app/ ./
RUN cargo build --release --bin app

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/target/release/app /usr/local/bin/app
ENV PORT=8081 RUST_LOG=info
EXPOSE 8081
USER nobody
ENTRYPOINT [ "/usr/local/bin/app" ]
