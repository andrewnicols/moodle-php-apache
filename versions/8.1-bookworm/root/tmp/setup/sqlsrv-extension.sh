#!/usr/bin/env bash

set -e

# Packages for build.
BUILD_PACKAGES="gnupg unixodbc-dev"

# Packages for sqlsrv runtime.
PACKAGES_SQLSRV="unixodbc"

# Note: These dependencies must be installed before installing the Microsoft source because there is a package in there
# which breaks the install.
echo "Installing apt dependencies"
apt-get update
apt-get install -y --no-install-recommends apt-transport-https \
    $BUILD_PACKAGES \
    $PACKAGES_SQLSRV

# Install Microsoft dependencies for sqlsrv
echo "Downloading sqlsrv files"
if [[ ${TARGETPLATFORM} == "linux/arm64" ]]; then
  curl -fsSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
  dpkg -i /tmp/packages-microsoft-prod.deb
  rm /tmp/packages-microsoft-prod.deb
else
  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
  # TODO, bookworm should be 12, but the msodbcsql17 package is not available yet, hence using bullseye (11) one.
  # (see https://learn.microsoft.com/en-us/answers/questions/1328834/debian-12-public-key-is-not-available)
  curl https://packages.microsoft.com/config/debian/10/prod.list -o /etc/apt/sources.list.d/mssql-release.list
fi
apt-get update

echo "Install msodbcsql"
if [[ ${TARGETPLATFORM} == "linux/arm64" ]]; then
  ACCEPT_EULA=Y apt-get install -y msodbcsql18
else
  ACCEPT_EULA=Y apt-get install -y msodbcsql17
  ln -fsv /opt/mssql-tools/bin/* /usr/bin
fi

# Need 5.10 (or later) for PHP 8.1 support
pecl install sqlsrv-5.11.0
docker-php-ext-enable sqlsrv

# Keep our image size down..
pecl clear-cache
apt-get remove --purge -y $BUILD_PACKAGES
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*
