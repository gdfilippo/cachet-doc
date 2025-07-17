FROM php:8.3-fpm

EXPOSE 8000
CMD ["/sbin/entrypoint.sh"]

ENV COMPOSER_VERSION 2.8.4

RUN apt update
RUN apt install -y libzip-dev libxml2-dev default-mysql-client postgresql-client supervisor nginx libpq-dev

RUN CFLAGS="-I/usr/src/php" docker-php-ext-install zip xmlreader intl
RUN docker-php-ext-enable zip intl xmlreader
RUN pecl install apcu && \
    docker-php-ext-enable apcu && \
    docker-php-ext-install pdo pdo_pgsql pdo_mysql && \
    pecl clear-cache

RUN apt install -y git wget


RUN cd /tmp ; wget https://getcomposer.org/installer -O /tmp/composer-setup.php && \
    wget https://composer.github.io/installer.sig -O /tmp/composer-setup.sig && \
    php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" && \
    php /tmp/composer-setup.php --version=$COMPOSER_VERSION --install-dir=/bin && \
    php -r "unlink('/tmp/composer-setup.php');"

RUN ln -s /usr/bin/composer.phar /usr/bin/composer

RUN cd /tmp && \
    git clone https://github.com/cachethq/cachet && \
    cd /tmp/cachet && \
    php /bin/composer.phar install --no-dev -o

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY gitToken/php/auth.json /root/.composer/auth.json

RUN  cd /tmp/cachet  && composer update cachethq/core && \
    rm -rf /var/www/html && \
    mv /tmp/cachet /var/www/html && \
    chown -R www-data:root /var/www/html

RUN touch /var/www/html/database/database.sqlite && chown www-data:root /var/www/html/database/database.sqlite

COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx-site.conf /etc/nginx/conf.d/default.conf
RUN cp /var/www/html/.env.example /var/www/html/.env
COPY entrypoint.sh /sbin/entrypoint.sh

RUN mkdir /var/cache/nginx && chmod 777 /var/cache/nginx