FROM alpine

RUN apk add strongswan xl2tpd ppp; rm -rf /var/cache/apk/*

ADD conf/ docker-entrypoint.sh /opt/src/

ENTRYPOINT ["/opt/src/docker-entrypoint.sh"]
