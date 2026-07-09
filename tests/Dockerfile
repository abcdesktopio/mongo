# syntax=docker/dockerfile:1.7
#
# Image d'outils de test CI/CD pour le dépôt abcdesktopio/mongo :
# hadolint (lint du Dockerfile) + trivy (scan de vulnérabilités) à versions épinglées.
#
# Contexte de build : ce dossier ci/ (voir Makefile à la racine du dépôt)
#   docker build -f ci/Dockerfile.test -t mongo-ci-tools ci/
#
# Versions surchargeables sans modifier ce fichier :
#   docker build -f ci/Dockerfile.test \
#     --build-arg HADOLINT_VERSION=v2.14.0 \
#     --build-arg TRIVY_VERSION=0.72.0 \
#     -t mongo-ci-tools ci/

ARG HADOLINT_VERSION=v2.14.0
ARG TRIVY_VERSION=0.72.0

# --- Récupération des binaires depuis les images officielles épinglées ---
FROM hadolint/hadolint:${HADOLINT_VERSION} AS hadolint-src
FROM aquasec/trivy:${TRIVY_VERSION} AS trivy-src

# --- Image finale ---
FROM alpine:3.20

# Re-déclarer les ARG après le FROM (portée perdue sinon)
ARG HADOLINT_VERSION=v2.14.0
ARG TRIVY_VERSION=0.72.0

LABEL org.opencontainers.image.description="Outils de test CI/CD pour abcdesktopio/mongo : hadolint ${HADOLINT_VERSION} + trivy ${TRIVY_VERSION}"

# bash requis par run-trivy.sh (bashismes : local, substitution ${var:0:n})
# docker-cli requis pour que trivy scanne des images locales via le socket monté
RUN apk add --no-cache \
        bash \
        jq \
        curl \
        docker-cli \
        ca-certificates \
        python3 \
        py3-pip

RUN pip3 install --no-cache-dir --break-system-packages junit2html        

COPY --from=hadolint-src /bin/hadolint /usr/local/bin/hadolint
COPY --from=trivy-src    /usr/local/bin/trivy /usr/local/bin/trivy

COPY bin/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh /usr/local/bin/*.py

# Vérifie que les binaires sont bien fonctionnels au build (fail-fast si version invalide)
RUN hadolint --version && trivy --version

# Template HTML officiel de Trivy, épinglé à LA MÊME version que le binaire
# (non embarqué dans le binaire, doit être récupéré séparément)
RUN mkdir -p /opt/trivy/contrib && \
    curl -fsSL "https://raw.githubusercontent.com/aquasecurity/trivy/v${TRIVY_VERSION}/contrib/html.tpl" \
         -o /opt/trivy/contrib/html.tpl

WORKDIR /workspace
         
# Pas d'ENTRYPOINT/CMD imposé : l'appelant (Makefile/CI) choisit la commande
CMD ["/bin/bash"]