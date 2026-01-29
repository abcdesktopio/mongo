# MongoDB Docker Image (8.0)

![CI](https://github.com/abcdesktopio/mongo/actions/workflows/docker-image.yml/badge.svg) ![Trivy](https://abcdesktopio.github.io/mongo/trivy.svg)

Secure and up-to-date MongoDB 8.0 Docker image for development and production.

## Features

- Recompiled MongoDB tools and binaries with the latest security patches (Go 1.25.6, js-yaml 3.14.2, etc.)
- Based on Ubuntu 24.04, regularly updated
- Continuous security scanning (Trivy)
- Easy to use and deploy

## Quick Start

Pull the image:
```
docker pull ghcr.io/abcdesktopio/mongo:safe8.0
```

Run a container:
```
docker run -d \
  --name mongo8 \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  ghcr.io/abcdesktopio/mongo:safe8.0
```

Access the Mongo shell:
```
docker exec -it mongo8 mongosh -u admin -p secret
```

Stop and remove the container:
```
docker stop mongo8
docker rm mongo8
```

## Security (Trivy Scan)

- All MongoDB tools, gosu, and js-yaml are fully patched (0 vulnerabilities)
- 20 vulnerabilities remain in the Ubuntu 24.04 base image (0 critical, 0 high, 8 medium, 12 low; no upstream fix yet)
- The image is rebuilt automatically when new fixes are available

---

This image is monitored and maintained for security and stability.
