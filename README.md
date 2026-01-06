# MongoDB Docker Image (8.0)

![CI](https://github.com/abcdesktopio/mongo/actions/workflows/docker-image.yml/badge.svg) ![Trivy](https://abcdesktopio.github.io/mongo/trivy.svg)

Secure and reliable MongoDB 8.0 Docker image with integrated CVE fixes, rebuilt binaries, and an up-to-date base OS. Ideal for both development and production.

## Key Features

- **Recompiled binaries** with latest Go 1.25.5 and patched dependencies:
  ```
  bsondump, mongodump, mongoexport, mongofiles, mongoimport, mongorestore, mongostat, mongotop, gosu
  ```

- **Patched security vulnerabilities**:
  - ✅ Go 1.25.5 (fixed CVE-2025-61729, CVE-2025-61727)
  - ✅ golang.org/x/crypto v0.45.0 (fixed CVE-2025-47914, CVE-2025-58181)
  - ✅ js-yaml 3.14.2 (fixed CVE-2025-64718)

- **Updated base OS**: `apt update && apt upgrade` ensures the latest security patches

- **Continuous security scanning**: Trivy badge reflects the current vulnerability status

- **Easy deployment**: ready-to-use, stable, and secure

## Trivy Security Scan Summary

| Target                                                | Type     | Vulnerabilities | Status                              |
| ----------------------------------------------------- | -------- | --------------- | ----------------------------------- |
| `ghcr.io/abcdesktopio/mongo:safe8.0` (Ubuntu 24.04)   | ubuntu   | 15              | Base OS CVEs — no fixes yet         |
| MongoDB tools & `gosu` (9 binaries)                   | gobinary | **0**           | ✅ Clean — All Go CVEs patched      |
| `opt/js-yaml/package.json`                            | node-pkg | **0**           | ✅ Clean — js-yaml patched to 3.14.2 |

**Last scan**: 8 December 2025

## Summary

- ✅ **All custom and recompiled binaries are fully patched** — 0 vulnerabilities
- ✅ **All critical Go and Node.js CVEs resolved**
- ⚠️ Remaining 15 vulnerabilities come from the Ubuntu 24.04 base image (all marked "affected" — no fixes available upstream)
- 🔄 Image is rebuilt and updated automatically when fixes are available

## Patched Vulnerabilities

### Go Vulnerabilities (Fixed)
- **CVE-2025-61729** (HIGH) — Go stdlib vulnerability
- **CVE-2025-61727** (MEDIUM) — Go stdlib vulnerability
- **CVE-2025-47914** (CRITICAL) — golang.org/x/crypto vulnerability
- **CVE-2025-58181** (HIGH) — golang.org/x/crypto vulnerability

### Node.js Vulnerabilities (Fixed)
- **CVE-2025-64718** (MEDIUM) — js-yaml code execution vulnerability

All MongoDB Database Tools and gosu binaries are compiled with the patched versions.

## Security Policy

- Regular Scans – Continuous Trivy scans monitor OS and binary vulnerabilities

- Patched Binaries – All MongoDB tools and gosu are recompiled with latest Go & libraries

- Base OS Updates – apt update && apt upgrade ensures up-to-date packages

- CVE Monitoring – Critical vulnerabilities are patched in rebuilt images promptly

- Community Reporting – Users can report security issues via GitHub Issues

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

Access Mongo shell:
```
docker exec -it mongo8 mongosh -u admin -p secret
```

Stop and remove the container:
```
docker stop mongo8
docker rm mongo8
```

## Why use this image?

- Secure, up-to-date, and patched binaries
- Monitored and rebuilt automatically for CVEs
- Ready for production and development environments
