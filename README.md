# MongoDB Docker Image (8.0)

![CI](https://github.com/abcdesktopio/mongo/actions/workflows/docker-image.yml/badge.svg) ![Trivy](https://abcdesktopio.github.io/mongo/trivy.svg)

Secure and up-to-date MongoDB 8.0 Docker image for development and production.

## Features

- MongoDB tools and binaries recompiled with the latest available security patches
- Based on a recent and regularly updated Ubuntu LTS base image
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

## Security

- All included binaries and dependencies are regularly updated and rebuilt with upstream security patches.
- The image is scanned automatically for vulnerabilities and rebuilt as needed.
- For details on the latest security status, refer to the Trivy scan badge and release notes.

---

This image is actively maintained for security and stability. For more information, see the documentation or open an issue.
