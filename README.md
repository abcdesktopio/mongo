# mongo

![CI](https://github.com/abcdesktopio/mongo/actions/workflows/docker-image.yml/badge.svg) ![Trivy](https://abcdesktopio.github.io/mongo/trivy.svg)

MongoDB docker image including cve fixes:
* add a recompiled /usr/locall/bin/gosu binary with last GO and libraries.
* add a layer to run `apt update` and `apt upgrade`.
  

