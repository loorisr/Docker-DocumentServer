# Stage 1: Fetcher (Downloads and prepares Oracle Instant Client)
FROM debian:bookworm-slim AS fetcher
RUN apt-get update && apt-get install -y --no-install-recommends unzip wget ca-certificates

ARG OC_PATH=2370000
ARG OC_FILE_SUFFIX=23.7.0.25.01
ENV OC_DOWNLOAD_URL=https://download.oracle.com/otn_software/linux/instantclient/${OC_PATH}

RUN wget -q -O basic.zip ${OC_DOWNLOAD_URL}/instantclient-basic-linux.x64-${OC_FILE_SUFFIX}.zip && \
    wget -q -O sqlplus.zip ${OC_DOWNLOAD_URL}/instantclient-sqlplus-linux.x64-${OC_FILE_SUFFIX}.zip && \
    mkdir -p /opt/oracle && \
    unzip -oq basic.zip -d /opt/oracle && \
    unzip -oq sqlplus.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_23_7 /opt/oracle/instantclient

# Stage 2: Final Image
FROM debian:bookworm-slim AS documentserver
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

# Set Environment Variables
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PG_VERSION=16 \
    COMPANY_NAME=onlyoffice \
    PRODUCT_NAME=documentserver \
    LD_LIBRARY_PATH=/usr/share/instantclient:$LD_LIBRARY_PATH

# 1. Fix Locales and Repositories (Enable contrib for fonts)
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list.d/debian.sources || \
    sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list

# 2. Install Core Dependencies
RUN echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg lsb-release ca-certificates apt-transport-https \
    adduser bomstrip certbot cron curl \
    libaio1 libasound2 libcairo2 libcurl3-gnutls libcurl4 libgtk-3-0 \
    libnspr4 libnss3 libstdc++6 libxml2 libxss1 libxtst6 \
    nginx-extras postgresql-client pwgen redis-server rabbitmq-server \
    supervisor ttf-mscorefonts-installer unixodbc-dev unzip xvfb xxd zlib1g && \
    # 3. Setup Microsoft SQL Tools (Debian 12 version)
    wget -q -O- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools18 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 4. Copy Oracle Client and Custom Assets
COPY --from=fetcher /opt/oracle/instantclient /usr/share/instantclient
COPY oracle/sqlplus /usr/bin/sqlplus
COPY fonts/ /usr/share/fonts/truetype/
COPY config/supervisor/supervisor /etc/init.d/
COPY config/supervisor/ds/*.conf /etc/supervisor/conf.d/
COPY run-document-server.sh /app/ds/run-document-server.sh

# 5. Install ONLYOFFICE Document Server
ARG PACKAGE_BASEURL="http://download.onlyoffice.com/install/documentserver/linux"
RUN TARGETARCH=$(dpkg --print-architecture) && \
    wget -q "${PACKAGE_BASEURL}/${COMPANY_NAME}-${PRODUCT_NAME}_${TARGETARCH}.deb" -O /tmp/ds.deb && \
    apt-get update && \
    # Install .deb and resolve dependencies automatically
    (dpkg -i /tmp/ds.deb || apt-get install -f -y) && \
    # Cleanup post-install
    rm /tmp/ds.deb && \
    chmod 755 /etc/init.d/supervisor && \
    chmod 755 /app/ds/*.sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

EXPOSE 80 443

VOLUME /var/log/$COMPANY_NAME /var/lib/$COMPANY_NAME /var/www/$COMPANY_NAME/Data /var/lib/postgresql /var/lib/rabbitmq /var/lib/redis /usr/share/fonts/truetype/custom

ENTRYPOINT ["/app/ds/run-document-server.sh"]
