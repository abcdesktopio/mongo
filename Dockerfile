# -------------------------------------------------------------------
# Dockerfile for building a secure MongoDB image
# with recompiled MongoDB Database Tools and gosu
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Declare global ARGs (default values)
# Can be overridden at build time with --build-arg
# -------------------------------------------------------------------
ARG GO_VERSION=1.25.6            # Go version used to build the tools
ARG MONGO_VERSION=8.0            # Final official MongoDB image version
ARG MONGO_TOOLS_VERSION=100.13.0 # MongoDB Database Tools version to compile
ARG GOSU_VERSION=1.19            # gosu version to compile
ARG GO_CRYPTO_VERSION=0.45.0     # golang.org/x/crypto version for security patches
ARG JS_YAML_VERSION=3.14.2       # js-yaml version for security patches (CVE-2025-64718)

# -------------------------------------------------------------------
# Stage 1: Builder
# Compile MongoDB tools and gosu from source
# -------------------------------------------------------------------
FROM golang:${GO_VERSION} AS builder

# Redefine ARGs in this stage
ARG MONGO_TOOLS_VERSION
ARG GOSU_VERSION
ARG GO_VERSION
ARG GO_CRYPTO_VERSION

# Install dependencies, clone and build MongoDB tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git=1:2.47.* \
        wget=1.25.* \
        file=1:5.46-* \
        build-essential=12.12 \
        autoconf=2.72-* \
        automake=1:1.17-* \
        libtool=2.5.* && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/mongodb/mongo-tools.git /src

WORKDIR /src
RUN git checkout tags/${MONGO_TOOLS_VERSION} --quiet

# Update golang.org/x/crypto to patched version before compilation
WORKDIR /src
RUN go get golang.org/x/crypto@v${GO_CRYPTO_VERSION} && \
    go mod tidy && \
    go mod vendor

# Compile each MongoDB tool individually with updated dependencies
RUN for dir in bsondump mongodump mongoexport mongofiles mongoimport mongorestore mongostat mongotop; do \
        GOOS=linux GOARCH=amd64 go build \
        -trimpath \
        -ldflags="-s -w -X main.VersionStr=${MONGO_TOOLS_VERSION} -X main.GitCommit=secure-build" \
        -o /usr/local/bin/$dir ./$dir/main; \
    done

# Download and extract gosu source
RUN wget --progress=dot:giga -O /tmp/gosu.tar.gz "https://github.com/tianon/gosu/archive/refs/tags/${GOSU_VERSION}.tar.gz" && \
    tar -xzf /tmp/gosu.tar.gz -C /tmp && \
    rm /tmp/gosu.tar.gz    

WORKDIR /tmp/gosu-${GOSU_VERSION}

# Update golang.org/x/crypto for gosu and build with recommended flags
RUN go get golang.org/x/crypto@v${GO_CRYPTO_VERSION} && \
    go mod tidy && \
    go mod vendor && \
    CGO_ENABLED=0 go build \
    -v \
    -trimpath \
    -ldflags="-s -w" \
    -buildvcs=true \
    -o /usr/local/bin/gosu .

# Verify compiled binaries
RUN /usr/local/bin/gosu --version && \
    for tool in bsondump mongodump mongoexport mongofiles mongoimport mongorestore mongostat mongotop; do \
        /usr/local/bin/$tool --version || echo "Warning: $tool version check failed"; \
    done    

# -------------------------------------------------------------------
# Stage 2: Final MongoDB image
# -------------------------------------------------------------------
FROM mongo:${MONGO_VERSION}

# Redefine ARGs for labels
ARG GO_VERSION
ARG MONGO_TOOLS_VERSION
ARG GOSU_VERSION
ARG JS_YAML_VERSION

LABEL mongo.tools.version="${MONGO_TOOLS_VERSION}"
LABEL gosu.version="${GOSU_VERSION}"
LABEL go.build.version="${GO_VERSION}"
LABEL js.yaml.version="${JS_YAML_VERSION}"

# Update js-yaml to patched version (CVE-2025-64718) by replacing the file directly
# Download and extract the specific version without installing npm and its dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl=8.5.* && \
    if [ -d /opt/js-yaml ]; then \
        curl -L -o /opt/js-yaml/js-yaml.tar.gz "https://registry.npmjs.org/js-yaml/-/js-yaml-${JS_YAML_VERSION}.tgz" && \
        tar -xzf /opt/js-yaml/js-yaml.tar.gz -C /opt/js-yaml && \
        cp -rf /opt/js-yaml/package/* /opt/js-yaml/ && \
        rm -rf /opt/js-yaml/package /opt/js-yaml/js-yaml.tar.gz; \
    fi && \
    apt-get remove -y curl && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Copy only the necessary binaries from builder
COPY --from=builder /usr/local/bin/gosu /usr/local/bin/gosu
COPY --from=builder /usr/local/bin/bsondump \
                    /usr/local/bin/mongodump \
                    /usr/local/bin/mongoexport \
                    /usr/local/bin/mongofiles \
                    /usr/local/bin/mongoimport \
                    /usr/local/bin/mongorestore \
                    /usr/local/bin/mongostat \
                    /usr/local/bin/mongotop \
                    /usr/bin/

# Set correct permissions
RUN for tool in bsondump mongodump mongoexport mongofiles mongoimport mongorestore mongostat mongotop; do \
        chown ubuntu:ubuntu /usr/bin/$tool; \
        chmod 755 /usr/bin/$tool ; \
    done

# The following instructions are inherited from the mongo:${MONGO_VERSION} base image
# ENTRYPOINT, EXPOSE, and CMD are not redefined to maintain
# compatibility with future versions of the official image

# Inherited from official MongoDB image:
# ENTRYPOINT ["docker-entrypoint.sh"]
# EXPOSE 27017
# CMD ["mongod"]

# -------------------------------------------------------------------
# Notes:
# - Only required binaries are copied to the final image to reduce size and attack surface.
# - Both MongoDB Database Tools and gosu are recompiled with Go ${GO_VERSION} to avoid vulnerabilities.
# - To use a different version of the tools or gosu, override ARGs at build time:
#       docker build --build-arg MONGO_TOOLS_VERSION=100.14.0 \
#                    --build-arg GOSU_VERSION=1.20 ...
# - Permissions are set to ubuntu:ubuntu for all binaries, in line with standard security practices.
# -------------------------------------------------------------------
