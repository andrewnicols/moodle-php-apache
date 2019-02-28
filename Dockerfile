FROM php:7.1-apache-stretch

ARG DEBIAN_FRONTEND=noninteractive

# Install NVM and the current (as of 26/02/2019) LTS version of Node.
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION lts/carbon
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash && \
    . $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm use --delete-prefix $NODE_VERSION

# Build packages will be added during the build, but will be removed at the end.
ENV BUILD_PACKAGES \
        gettext gnupg libcurl4-openssl-dev libfreetype6-dev libicu-dev libjpeg62-turbo-dev \
        libldap2-dev libmariadbclient-dev libmemcached-dev libpng-dev libpq-dev libxml2-dev libxslt-dev \
        zlib1g-dev

# Packages for Postgres.
ENV PACKAGES_POSTGRES libpq5

# Packages for MariaDB and MySQL.
ENV PACKAGES_MYMARIA libmariadbclient18

# Packages for other Moodle runtime dependenices.
ENV PACKAGES_RUNTIME ghostscript libaio1 libcurl3 libgss3 libicu57 libmcrypt-dev libxml2 libxslt1.1 \
    locales sassc unzip unixodbc sassc

# Packages required for moodle-local_ci.
ENV PACKAGES_CI git

# Packages for Memcached.
ENV PACKAGES_MEMCACHED libmemcached11 libmemcachedutil2

# Packages for LDAP.
ENV PACKAGES_LDAP libldap-2.4-2

ENV PHP_EXTENSIONS intl \
        mysqli \
        opcache \
        pgsql \
        soap \
        xsl \
        xmlrpc \
        zip

# Install the standard PHP extensions.
RUN apt-get update; apt-get install -y --no-install-recommends apt-transport-https \
        $BUILD_PACKAGES \
        $PACKAGES_POSTGRES \
        $PACKAGES_MYMARIA \
        $PACKAGES_RUNTIME \
        $PACKAGES_MEMCACHED \
        $PACKAGES_LDAP \
        $PACKAGES_CI; \
    echo 'Generating locales..'; \
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen; \
    echo 'en_AU.UTF-8 UTF-8' >> /etc/locale.gen; \
    locale-gen; \
\
    echo "Installing php extensions"; \
    docker-php-ext-install -j$(nproc) $PHP_EXTENSIONS; \
\
    # GD.
    docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/; \
    docker-php-ext-install -j$(nproc) gd; \
\
    # LDAP.
    docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/; \
    docker-php-ext-install -j$(nproc) ldap; \
\
    # SOLR, Memcached, Redis, APCu, igbinary.
    pecl install solr memcached redis apcu igbinary; \
    docker-php-ext-enable solr memcached redis apcu igbinary; \
\
    echo 'apc.enable_cli = On' >> /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini; \
\
    # Keep our image size down..
    pecl clear-cache; \
    apt-get remove --purge -y $BUILD_PACKAGES; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Install the MSSQL Extension.
ENV BUILD_PACKAGES gnupg unixodbc-dev

RUN apt-get update; apt-get install -y --no-install-recommends apt-transport-https $BUILD_PACKAGES; \
\
    # Install Microsoft dependcies for sqlsrv.
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -; \
    curl https://packages.microsoft.com/config/debian/9/prod.list -o /etc/apt/sources.list.d/mssql-release.list; \
    apt-get update; \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17; \
\
    pecl install sqlsrv; \
    docker-php-ext-enable sqlsrv; \
\
    # Keep our image size down.
    pecl clear-cache; \
    apt-get remove --purge -y $BUILD_PACKAGES; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Install the PHP OCI8 Extension.
ENV LD_LIBRARY_PATH /usr/local/instantclient

ENV ORACLE_BASE_PATH https://raw.githubusercontent.com/AminMkh/docker-php7-oci8-apache/b7c740638776552f00178a5d12905cefb50c7848/oracle/
ENV ORACLE_VERSION 12.1.0.2.0

RUN \
    curl $ORACLE_BASE_PATH/instantclient-basic-linux.x64-$ORACLE_VERSION.zip -o /tmp/instantclient-basic-linux.x64-$ORACLE_VERSION.zip; \
    curl $ORACLE_BASE_PATH/instantclient-sdk-linux.x64-$ORACLE_VERSION.zip -o /tmp/instantclient-sdk-linux.x64-$ORACLE_VERSION.zip; \
    curl $ORACLE_BASE_PATH/instantclient-sqlplus-linux.x64-$ORACLE_VERSION.zip -o /tmp/instantclient-sqlplus-linux.x64-$ORACLE_VERSION.zip; \
    unzip /tmp/instantclient-basic-linux.x64-$ORACLE_VERSION.zip -d /usr/local/; \
    unzip /tmp/instantclient-sdk-linux.x64-$ORACLE_VERSION.zip -d /usr/local/; \
    unzip /tmp/instantclient-sqlplus-linux.x64-$ORACLE_VERSION.zip -d /usr/local/; \
    rm /tmp/instantclient-*x64-$ORACLE_VERSION.zip; \
\
    ln -s /usr/local/instantclient_12_1 /usr/local/instantclient; \
    ln -s /usr/local/instantclient/libclntsh.so.12.1 /usr/local/instantclient/libclntsh.so; \
    ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus; \
\
    echo 'instantclient,/usr/local/instantclient' | pecl install oci8 && docker-php-ext-enable oci8; \
    echo 'oci8.statement_cache_size = 0' >> /usr/local/etc/php/conf.d/docker-php-ext-oci8.ini; \
\
    # Keep our image size down.
    pecl clear-cache

# Set the custom entrypoint.
ADD moodle-php-entrypoint /usr/local/bin/
ENTRYPOINT ["moodle-php-entrypoint"]
CMD ["apache2-foreground"]
