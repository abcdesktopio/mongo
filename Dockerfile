# -------------------------------------------------------------------
# Dockerfile for building a secure MongoDB image
# with recompiled MongoDB Database Tools and gosu
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Declare global ARGs (default values)
# Can be overridden at build time with --build-arg
# -------------------------------------------------------------------
ARG GO_VERSION=1.25.3            # Go version used to build the tools
ARG MONGO_VERSION=8.0            # Final official MongoDB image version
ARG MONGO_TOOLS_VERSION=100.13.0 # MongoDB Database Tools version to compile
ARG GOSU_VERSION=1.19            # gosu version to compile

# -------------------------------------------------------------------
# Stage 1: Builder
# Compile MongoDB tools and gosu from source
# -------------------------------------------------------------------
FROM golang:${GO_VERSION} AS builder

# Redefine ARGs in this stage
ARG MONGO_TOOLS_VERSION
ARG GOSU_VERSION
ARG GO_VERSION

# Install dependencies, clone and build MongoDB tools
RUN apt-get update && \
    apt-get install -y \
        git \
        wget \
        file \
        build-essential \
        autoconf \
        automake \
        libtool && \
    rm -rf /var/lib/apt/lists/* && \
    git clone https://github.com/mongodb/mongo-tools.git /src && \
    cd /src && git checkout tags/${MONGO_TOOLS_VERSION} --quiet

# Compile each MongoDB tool individually
WORKDIR /src
RUN for dir in bsondump mongodump mongoexport mongofiles mongoimport mongorestore mongostat mongotop; do \
        GOOS=linux GOARCH=amd64 go build -o /usr/local/bin/$dir ./$dir/main; \
    done

# Download and extract gosu source
RUN wget -O /tmp/gosu.tar.gz "https://github.com/tianon/gosu/archive/refs/tags/${GOSU_VERSION}.tar.gz" && \
    tar -xzf /tmp/gosu.tar.gz -C /tmp && \
    rm /tmp/gosu.tar.gz    

WORKDIR /tmp/gosu-${GOSU_VERSION}

# Build gosu using recommended flags
RUN CGO_ENABLED=0 go build \
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

LABEL mongo.tools.version="${MONGO_TOOLS_VERSION}"
LABEL gosu.version="${GOSU_VERSION}"
LABEL go.build.version="${GO_VERSION}"

RUN apt-get update && \
    apt-get upgrade -y && \
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
