# Stage 1: Extraction stage for Oracle and Microsoft assets
FROM debian:bookworm-slim AS fetcher
RUN apt-get update && apt-get install -y unzip wget
ARG OC_PATH=2326000
ARG OC_FILE_SUFFIX=23.26.0.0.0
ENV OC_DOWNLOAD_URL=https://download.oracle.com/otn_software/linux/instantclient/${OC_PATH}

RUN wget -q -O basic.zip ${OC_DOWNLOAD_URL}/instantclient-basic-linux.x64-${OC_FILE_SUFFIX}.zip && \
    wget -q -O sqlplus.zip ${OC_DOWNLOAD_URL}/instantclient-sqlplus-linux.x64-${OC_FILE_SUFFIX}.zip && \
    mkdir -p /opt/oracle && \
    unzip basic.zip -d /opt/oracle && \
    unzip sqlplus.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_* /opt/oracle/instantclient

# Stage 2: Final Image
FROM debian:bookworm-slim AS documentserver
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive \
    PG_VERSION=16 \
    COMPANY_NAME=onlyoffice \
    PRODUCT_NAME=documentserver

# Install only essential dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg locales lsb-release ca-certificates apt-transport-https \
    # Core app dependencies (pruned)
    adduser bomstrip certbot cron curl libaio1t64 libasound2t64 libcairo2 \
    libcurl3-gnutls libcurl4 libgtk-3-0 libnspr4 libnss3 libstdc++6 libxml2 \
    libxss1 libxtst6 nginx-extras postgresql-client pwgen redis-server \
    rabbitmq-server supervisor ttf-mscorefonts-installer unixodbc-dev \
    unzip xvfb xxd zlib1g && \
    # Setup locales
    locale-gen en_US.UTF-8 && \
    # Setup Microsoft Repo
    wget -q -O- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools18 && \
    # Cleanup
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy assets from fetcher stage
COPY --from=fetcher /opt/oracle/instantclient /usr/share/instantclient
COPY oracle/sqlplus /usr/bin/sqlplus
COPY fonts/ /usr/share/fonts/truetype/

# Document Server Installation
ARG PACKAGE_BASEURL="http://download.onlyoffice.com/install/documentserver/linux"
RUN TARGETARCH=$(dpkg --print-architecture) && \
    wget -q "${PACKAGE_BASEURL}/${COMPANY_NAME}-${PRODUCT_NAME}_${TARGETARCH}.deb" -O /tmp/ds.deb && \
    # Use dpkg and fix-broken to keep layers small
    apt-get update && \
    (dpkg -i /tmp/ds.deb || apt-get install -f -y) && \
    rm /tmp/ds.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 80 443
VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /var/lib/postgresql

ENTRYPOINT ["/app/ds/run-document-server.sh"]
