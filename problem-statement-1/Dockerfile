FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG en_US.utf8

ENV PATH="/usr/games:${PATH}"

RUN apt update && apt install -y fortune-mod cowsay netcat-openbsd

WORKDIR /app

COPY wisecow.sh /app/wisecow.sh

RUN chmod +x /app/wisecow.sh

EXPOSE 4499

CMD [ "./wisecow.sh" ]
