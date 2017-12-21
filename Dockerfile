FROM php:7-apache

MAINTAINER Pha Vo <phavo@minhhungland.vn>

# Ensure UTF-8
RUN apt-get clean && apt-get -y update && apt-get -y install apt-utils &&\
    apt-get -y update && \
    apt-get -y install locales && \
    dpkg-reconfigure locales && \
    sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && \
    locale-gen en_US.UTF-8

ENV LANGUAGE   en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

ENV HOME /root

ENV DEBIAN_FRONTEND noninteractive

RUN echo "Asia/Ho_Chi_Minh" > /etc/timezone \
    dpkg-reconfigure -f noninteractive tzdata
#copy default ini
COPY ./docker/php.ini /usr/local/etc/php/
# Install memcached
RUN apt-get -y update
RUN buildDeps=" acl \
                git \
                libmemcached-dev \
                zlib1g-dev \
                libcurl4-gnutls-dev curl\
                libpng-dev lynx-cur python-setuptools \
                zlib1g-dev libicu-dev  g++ libtidy-dev libbz2-dev \
                libmagickwand-dev \
        " \
        && doNotUninstall=" \
                libmemcached11 \
                libmemcachedutil2 \
        " \
        && apt-get install -y $buildDeps --no-install-recommends \
        \
        && docker-php-source extract \
        && git clone --branch php7 https://github.com/php-memcached-dev/php-memcached /usr/src/php/ext/memcached/ \
        && docker-php-ext-install -j$(nproc) opcache curl gd intl tidy bcmath sockets \
                                bz2 mbstring gettext zip  mysqli pdo pdo_mysql shmop memcached \
        \
        && docker-php-source delete \
        && apt-mark manual $doNotUninstall
# Install APCu and APC backward compatibility
RUN pecl install apcu \
    && pecl install apcu_bc-1.0.3 \
    && docker-php-ext-enable apcu --ini-name 10-docker-php-ext-apcu.ini \
    && docker-php-ext-enable apc --ini-name 20-docker-php-ext-apc.ini
# Install apache, and supplimentary programs. curl and lynx-cur are for debugging the container.
RUN pecl install imagick && \
    docker-php-ext-enable imagick && \
    docker-php-ext-configure intl && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
	a2enmod rewrite
# Enable mod_expires
RUN cp /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/
ADD docker/apache-config.conf /etc/apache2/sites-enabled/000-default.conf
ENV APACHE_LOG_DIR /var/log/apache2

# Clean repository
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy source directory to default apache root directory
ADD ./symfony /var/www/html

COPY ./docker/docker-php-entrypoint /usr/local/bin/
RUN ls -la /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-php-entrypoint

RUN sed -ie 's/memory_limit\ =\ 128M/memory_limit\ =\ 2G/g' /usr/local/etc/php/php.ini && \
	sed -ie 's/\;date\.timezone\ =/date\.timezone\ =\ Asia\/Ho_Chi_Minh/g' /usr/local/etc/php/php.ini && \
	sed -ie 's/upload_max_filesize\ =\ 2M/upload_max_filesize\ =\ 200M/g' /usr/local/etc/php/php.ini && \
	sed -ie 's/post_max_size\ =\ 8M/post_max_size\ =\ 200M/g' /usr/local/etc/php/php.ini && \
	sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /usr/local/etc/php/php.ini && \
    service apache2 restart

RUN HTTPDUSER=$(ps axo user,comm | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1) && \
    setfacl -dR -m u:"$HTTPDUSER":rwX -m u:$(whoami):rwX var && \
    setfacl -R -m u:"$HTTPDUSER":rwX -m u:$(whoami):rwX var
