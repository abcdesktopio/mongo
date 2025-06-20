FROM mongo:4.4

ARG TARGETPLATFORM
RUN apt update|| true \
 && apt upgrade -y \
 && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
 && curl -L https://github.com/abcdesktopio/gosu/releases/download/1.17/gosu-$(echo "$TARGETPLATFORM"|cut -d'/' -f 2) \
         -o /usr/local/bin/gosu
