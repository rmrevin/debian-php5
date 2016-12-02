FROM php:5.6-fpm

MAINTAINER Revin Roman <roman@rmrevin.com>

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends \
        apt-utils bash-completion ca-certificates chrpath net-tools ssh-client \
        curl wget rsync git vim unzip bzip2

ARG GOSU_VERSION=1.10
RUN set -xe \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

ONBUILD ARG _UID
ONBUILD ARG _GID

ONBUILD RUN groupadd -g $_GID www-data \
 && useradd -g $_GID -u $_UID -s /bin/bash www-data \
 && echo "    IdentityFile ~/.ssh/id_rsa" >> /etc/ssh/ssh_config

RUN mkdir -p /var/run/php/ \
 && mkdir -p /var/log/php/ \
 && mkdir -p /var/log/app/ \
 && chown www-data:www-data /var/www/

RUN set -xe \
 && apt-key adv --keyserver pgp.mit.edu --recv-keys 5072E1F5 \
 && echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-apt-config" >> /etc/apt/sources.list.d/mysql.list \
 && echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-5.7" >> /etc/apt/sources.list.d/mysql.list \
 && echo "deb-src http://repo.mysql.com/apt/debian/ jessie mysql-5.7" >> /etc/apt/sources.list.d/mysql.list \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends mysql-client

RUN set -xe \
 && docker-php-ext-install -j$(nproc) pdo pdo_mysql mysqli opcache pcntl shmop sockets

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends libmcrypt-dev \
 && docker-php-ext-install -j$(nproc) mcrypt

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends libicu-dev libicu52 \
 && docker-php-ext-install -j$(nproc) intl

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends libzip-dev \
 && docker-php-ext-install -j$(nproc) zip

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends libfreetype6-dev libjpeg62-turbo-dev libpng12-dev \
 && docker-php-ext-install -j$(nproc) gd

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends libmagickwand-dev \
 && pecl install imagick-3.4.2 \
 && docker-php-ext-enable imagick

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends geoip-database libgeoip-dev \
 && pecl install geoip-1.1.1 \
 && docker-php-ext-enable geoip

RUN set -xe \
 && mkdir /usr/local/share/GeoIP/ \
 && cd /usr/local/share/GeoIP/ \
 && curl -O "http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz" 2>&1 \
 && gunzip GeoLite2-City.mmdb.gz

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends libssl-dev \
 && pecl install mongodb-1.2.0alpha3 \
 && docker-php-ext-enable mongodb

RUN set -xe \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends supervisor

#COPY supervisor.d/ /etc/supervisor/

#ARG PROJECT
#RUN sed -i -- "s/<PROJECT>/$PROJECT/g" /etc/supervisor/conf.d/*.conf

ONBUILD ARG GITHUB_OAUTH_TOKEN

ONBUILD RUN set -xe \
 && cd /opt \
 && curl -sS https://getcomposer.org/installer | php \
 && ln -s /opt/composer.phar /usr/local/bin/composer \
 #&& ln -s /var/www/backend/bin/yii /usr/local/bin/yii \
 #&& ln -s /var/www/backend/bin/build /usr/local/bin/build \
 && gosu www-data composer config -g github-oauth.github.com $GITHUB_OAUTH_TOKEN \
 && gosu www-data composer global require "fxp/composer-asset-plugin:^1.2.0"

ONBUILD ARG _ENV

ONBUILD COPY php.$_ENV.ini /usr/local/etc/php/php.ini
ONBUILD COPY php-fpm.d/www.conf /usr/local/etc/php-fpm.d/www.conf

RUN rm -rf /var/lib/apt/lists/*

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]

WORKDIR /var/www/
