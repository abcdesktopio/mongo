FROM mongo:8.0.14-noble

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*
