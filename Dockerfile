FROM alpine:3.21

LABEL description="Simple DNS authoritative server with DNSSEC support" \
      maintainer="MXServer <admin@msync.work>"

ARG NSD_VERSION=4.11.1

# https://pgp.mit.edu/pks/lookup?search=0x7E045F8D&fingerprint=on&op=index
# pub  4096R/7E045F8D 2011-04-21 W.C.A. Wijngaards <wouter@nlnetlabs.nl>
ARG GPG_SHORTID="DC34EE5DB2417BCC151E5100E5F8F8212F77A498"
ARG GPG_FINGERPRINT="DC34 EE5D B241 7BCC 151E  5100 E5F8 F821 2F77 A498"
ARG SHA256_HASH="696e50052008de4fa7ab1d818d5b77eb63247eea2f0575114c9592ff9188a614"

ENV UID=991 GID=991

RUN apk add --no-cache --virtual build-dependencies \
      gnupg \
      build-base \
      libevent-dev \
      openssl-dev \
      ca-certificates \
 && apk add --no-cache \
      ldns \
      ldns-tools \
      libevent \
      openssl \
      tini \
 && cd /tmp \
 && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz \
 && wget -q https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz.asc \
 && echo "Verifying both integrity and authenticity of nsd-${NSD_VERSION}.tar.gz..." \
 && CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') \
 && if [ "${CHECKSUM}" != "${SHA256_HASH}" ]; then echo "ERROR: Checksum does not match!" && exit 1; fi \
 && ( \
    gpg --keyserver keyserver.ubuntu.com --recv-keys ${GPG_SHORTID} || \
    gpg --keyserver keyserver.pgp.com --recv-keys ${GPG_SHORTID} || \
    gpg --keyserver pgp.mit.edu --recv-keys ${GPG_SHORTID} || \
    wget -qO - https://keys.openpgp.org/vks/v1/by-fingerprint/${GPG_SHORTID} | gpg --import \
    ) \
 && FINGERPRINT="$(LANG=C gpg --verify nsd-${NSD_VERSION}.tar.gz.asc nsd-${NSD_VERSION}.tar.gz 2>&1 \
  | sed -n "s#Primary key fingerprint: \(.*\)#\1#p")" \
 && if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi \
 && if [ "${FINGERPRINT}" != "${GPG_FINGERPRINT}" ]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi \
 && echo "All seems good, now unpacking nsd-${NSD_VERSION}.tar.gz..." \
 && tar xzf nsd-${NSD_VERSION}.tar.gz && cd nsd-${NSD_VERSION} \
 && ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" \
 && make && make install \
 && apk del build-dependencies \
 && rm -rf /var/cache/apk/* /tmp/* /root/.gnupg

COPY bin /usr/local/bin
VOLUME /zones /etc/nsd /var/db/nsd
EXPOSE 53 53/udp
CMD ["run.sh"]
