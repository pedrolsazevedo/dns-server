FROM ubuntu:noble
RUN apt-get update \
    && apt-get install -y --no-install-recommends bind9 bind9-utils \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/bind /run/named \
    && chown bind:bind /var/log/bind /run/named
EXPOSE 53/udp 53/tcp 953/tcp
CMD ["named", "-g", "-c", "/etc/bind/named.conf", "-u", "bind"]
