FROM alpine:latest

WORKDIR /home/app

RUN apk update &&  \
    apk add tzdata --no-cache &&  \
    apk add bash --no-cache &&  \
    apk add wget --no-cache &&  \
    apk add tar --no-cache &&  \
    apk add openssh-client --no-cache &&  \
    apk add rsync --no-cache

COPY app/ ./

ENTRYPOINT ["./entrypoint.sh"]
