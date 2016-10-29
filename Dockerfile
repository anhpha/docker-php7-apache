FROM ubuntu:16.04

MAINTAINER Pha Vo <phavo@minhhungland.vn>

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

ENV HOME /root

RUN echo "Asia/Ho_Chi_Minh" > /etc/timezone \
    dpkg-reconfigure -f noninteractive tzdata

# Install apache, and supplimentary programs. curl and lynx-cur are for debugging the container.
RUN apt-get update && apt-get -y upgrade && DEBIAN_FRONTEND=noninteractive && \
    apt-get -y install apache2 supervisor wget
RUN sed -ie '$a\ServerName jinn-service-locationi' /etc/apache2/apache2.conf

# php
RUN apt-get update && apt-get -y upgrade && DEBIAN_FRONTEND=noninteractive apt-get -y install \
    apache2 php7.0 libapache2-mod-php7.0 php7.0-curl curl lynx-cur python-setuptools \
    php7.0-gd php7.0-mcrypt php7.0-intl php7.0-tidy collectd python-pip

# Enable mod_expires
RUN cp /etc/apache2/mods-available/expires.load /etc/apache2/mods-enabled/
ADD docker/apache-config.conf /etc/apache2/sites-enabled/000-default.conf
ENV APACHE_LOG_DIR /var/log/apache2
# Enable apache mods.
RUN a2enmod php7.0 && \
    a2enmod rewrite

#remove default html folder
RUN rm -r /var/www/html
# Copy source directory to default apache root directory
ADD ./docker/www /var/www/web
RUN service apache2 restart
	
RUN sed -ie 's/memory_limit\ =\ 128M/memory_limit\ =\ 2G/g' /etc/php/7.0/apache2/php.ini && \
	sed -ie 's/\;date\.timezone\ =/date\.timezone\ =\ Asia\/Ho_Chi_Minh/g' /etc/php/7.0/apache2/php.ini && \
	sed -ie 's/upload_max_filesize\ =\ 2M/upload_max_filesize\ =\ 200M/g' /etc/php/7.0/apache2/php.ini && \
	sed -ie 's/post_max_size\ =\ 8M/post_max_size\ =\ 200M/g' /etc/php/7.0/apache2/php.ini && \
	sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/7.0/apache2/php.ini && \
	sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php/7.0/apache2/php.ini

# Manually set up the apache environment variables
ENV "APACHE_RUN_USER"="www-data" "APACHE_RUN_GROUP"="www-data" \
	"APACHE_LOG_DIR"="/var/log/apache2" "APACHE_LOCK_DIR"="/var/lock/apache2" \
	"APACHE_PID_FILE"="/var/run/apache2.pid"

EXPOSE 80

ADD docker/supervisord.conf /etc/supervisord.conf
ADD	docker/collectd-config.conf.tpl /etc/collectd/configs/collectd-config.conf.tpl
RUN pip install --upgrade pip && pip install envtpl

ADD docker/start.sh /start.sh
ADD docker/foreground.sh /etc/apache2/foreground.sh
RUN chmod 755 /start.sh && \
	chmod 755 /etc/apache2/foreground.sh

# By default, start supervisord
CMD ["/bin/bash", "/start.sh"]