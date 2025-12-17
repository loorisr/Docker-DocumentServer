FROM debian:bookworm-slim AS documentserver
LABEL maintainer Ascensio System SIA <support@onlyoffice.com>

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 DEBIAN_FRONTEND=noninteractive \
    PG_VERSION=16 \
    COMPANY_NAME=onlyoffice \
    PRODUCT_NAME=documentserver

# 1. Enable 'contrib' and 'non-free' for fonts
RUN sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list.d/debian.sources || \
    sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list

# 2. Install essential dependencies with correct Debian names
RUN apt-get update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get install -y --no-install-recommends \
    wget gnupg locales lsb-release ca-certificates apt-transport-https \
    adduser bomstrip certbot cron curl \
    libaio1 \
    libasound2 \
    libcairo2 libcurl3-gnutls libcurl4 libgtk-3-0 libnspr4 libnss3 libstdc++6 libxml2 \
    libxss1 libxtst6 nginx-extras postgresql-client pwgen redis-server \
    rabbitmq-server supervisor ttf-mscorefonts-installer unixodbc-dev \
    unzip xvfb xxd zlib1g && \
    # Setup locales
    locale-gen en_US.UTF-8 && \
    # Setup Microsoft Repo (specific to Debian 12 Bookworm)
    wget -q -O- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft-prod.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y mssql-tools18 && \
    # Cleanup
    apt-get clean && rm -rf /var/lib/apt/lists/*
