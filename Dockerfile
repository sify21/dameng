FROM debian:12-slim AS installer

ARG DM_PACKAGE=dm8_20240712_x86_rh7_64.zip
ARG DM_ISO_SHA256=bdc89febd19ef051050b47446c21f2354aa03aba0e6cca1f98e3c51d35fdcaf5

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libaio1 \
        libarchive-tools \
        libnuma1 \
        passwd \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 dinstall \
    && useradd --uid 10001 --gid dinstall --create-home \
        --home-dir /home/dmdba --shell /bin/bash dmdba \
    && install -d -o dmdba -g dinstall /opt/dmdbms

COPY ${DM_PACKAGE} /tmp/dm-package.zip
COPY dm-install.xml /tmp/dm-install.xml

# Docker 构建中不能依赖 loop mount，因此直接用 bsdtar 解包 ZIP 和 ISO。
RUN set -eux; \
    mkdir -p /tmp/package /tmp/iso; \
    bsdtar -xf /tmp/dm-package.zip -C /tmp/package; \
    iso_file="$(find /tmp/package -maxdepth 1 -type f -name '*.iso' -print -quit)"; \
    test -n "${iso_file}"; \
    printf '%s  %s\n' "${DM_ISO_SHA256}" "${iso_file}" | sha256sum -c -; \
    bsdtar -xf "${iso_file}" -C /tmp/iso; \
    installer_file="$(find /tmp/iso -type f -name 'DMInstall.bin' -print -quit)"; \
    test -n "${installer_file}"; \
    install -o dmdba -g dinstall -m 0755 "${installer_file}" /tmp/DMInstall.bin; \
    chown dmdba:dinstall /tmp/dm-install.xml; \
    su -s /bin/bash dmdba -c '/tmp/DMInstall.bin -q /tmp/dm-install.xml'; \
    rm -rf /tmp/DMInstall.bin /tmp/dm-install.xml /tmp/dm-package.zip \
        /tmp/package /tmp/iso


FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gosu \
        libaio1 \
        libnuma1 \
        passwd \
        procps \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 dinstall \
    && useradd --uid 10001 --gid dinstall --create-home \
        --home-dir /home/dmdba --shell /bin/bash dmdba

ENV DM_HOME=/opt/dmdbms \
    DM_DATA_PATH=/opt/dmdbms/data \
    LD_LIBRARY_PATH=/opt/dmdbms/bin \
    DB_NAME=DAMENG \
    INSTANCE_NAME=dm8_01 \
    PORT_NUM=5236 \
    PAGE_SIZE=16 \
    CASE_SENSITIVE=1 \
    UNICODE_FLAG=1 \
    ARCH_FLAG=0 \
    SYSDBA_PWD=SYSDBA_dm001 \
    SYSAUDITOR_PWD=SYSAUDITOR_dm001

ENV PATH="${DM_HOME}/bin:${PATH}"

COPY --from=installer --chown=dmdba:dinstall /opt/dmdbms /opt/dmdbms
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && install -d -o dmdba -g dinstall "${DM_DATA_PATH}"

WORKDIR /home/dmdba

VOLUME ["/opt/dmdbms/data"]
EXPOSE 5236

HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
    CMD bash -c 'exec 3<>"/dev/tcp/127.0.0.1/${PORT_NUM}"' || exit 1

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["dmserver"]
