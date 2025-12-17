FROM debian:bookworm-slim AS fetcher
RUN apt-get update && apt-get install -y unzip wget
ARG OC_PATH=2370000
ARG OC_FILE_SUFFIX=23.7.0.25.01
ENV OC_DOWNLOAD_URL=https://download.oracle.com/otn_software/linux/instantclient/${OC_PATH}

RUN wget -q -O basic.zip ${OC_DOWNLOAD_URL}/instantclient-basic-linux.x64-${OC_FILE_SUFFIX}.zip && \
    wget -q -O sqlplus.zip ${OC_DOWNLOAD_URL}/instantclient-sqlplus-linux.x64-${OC_FILE_SUFFIX}.zip && \
    mkdir -p /opt/oracle && \
    unzip basic.zip -d /opt/oracle && \
    unzip sqlplus.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient_* /opt/oracle/instantclient

FROM debian:bookworm-slim AS documentserver
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

# 1. Setup Environment & Locales
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y locales && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    # 2. Add Contrib/Non-Free and update
    sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list.d/debian.sources || \
    sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list && \
    # 3. Pre-seed EULA for fonts
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    # 4. Install minimized dependency list
    apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg lsb-release ca-certificates apt-transport-https \
    adduser bomstrip certbot cron curl libaio1 libasound2 libcairo2 \
    libcurl3-gnutls libcurl4 libgtk-3-0 libnspr4 libnss3 libstdc++6 libxml2 \
    libxss1 libxtst6 nginx-extras postgresql-client pwgen redis-server \
    rabbitmq-server supervisor ttf-mscorefonts-installer unixodbc-dev \
    unzip xvfb xxd zlib1g && \
    # 5. Microsoft SQL Tools
    wget -q -O- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools18 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=fetcher /opt/oracle/instantclient /usr/share/instantclient
# ... (rest of your COPY and configuration commands) ...

ENTRYPOINT ["/app/ds/run-document-server.sh"]
