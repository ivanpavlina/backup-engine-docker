FROM python:3.10.5-alpine

WORKDIR /home/app

RUN apk update &&  \
    apk add tzdata --no-cache && apk add bash --no-cache &&  \
    apk add wget --no-cache && apk add openssh-client --no-cache

COPY app/ ./

ENTRYPOINT ["./entrypoint.sh"]
