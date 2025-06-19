FROM mongo:4.4

RUN apt update||true \
 && apt upgrade -y
