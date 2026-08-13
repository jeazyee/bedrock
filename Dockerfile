FROM php:8.3-fpm-bookworm AS php-base

COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN install-php-extensions \
        bcmath \
        exif \
        gd \
        imagick \
        intl \
        mysqli \
        opcache \
        pdo_mysql \
        redis \
        zip \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ghostscript \
        less \
        libfcgi-bin \
        mariadb-client \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

WORKDIR /var/www/html

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1 \
    WP_CLI_ALLOW_ROOT=1

COPY docker/php/conf.d/00-bedrock.ini /usr/local/etc/php/conf.d/00-bedrock.ini
COPY docker/php/zz-www.conf /usr/local/etc/php-fpm.d/zz-bedrock.conf
COPY docker/php/entrypoint.sh /usr/local/bin/bedrock-entrypoint
RUN chmod +x /usr/local/bin/bedrock-entrypoint

ENTRYPOINT ["bedrock-entrypoint"]
CMD ["php-fpm"]

FROM php-base AS php-dev

COPY docker/php/conf.d/10-opcache-dev.ini /usr/local/etc/php/conf.d/10-opcache.ini

ENV COMPOSER_AUTO_INSTALL=1

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 >/dev/null 2>&1 || exit 1

FROM php-base AS php-build

COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --prefer-dist \
        --no-interaction \
        --no-progress \
        --optimize-autoloader \
        --no-scripts

COPY --chown=www-data:www-data . .
RUN composer dump-autoload --optimize --classmap-authoritative --no-dev \
    && php docker/php/enable-redis-cache.php \
    && mkdir -p web/app/uploads \
    && chown -R www-data:www-data /var/www/html

FROM php-build AS php

COPY docker/php/conf.d/10-opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 >/dev/null 2>&1 || exit 1

FROM nginx:stable-alpine AS nginx

COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/site.conf /etc/nginx/conf.d/default.conf
COPY docker/nginx/headers.conf /etc/nginx/headers.conf
COPY docker/nginx/fastcgi-php.conf /etc/nginx/fastcgi-php.conf
COPY --from=php-build --chown=nginx:nginx /var/www/html /var/www/html

RUN mkdir -p /var/cache/nginx/fastcgi \
    && chown -R nginx:nginx /var/cache/nginx

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --start-period=10s --retries=5 \
    CMD wget -qO- http://127.0.0.1/health >/dev/null 2>&1 || exit 1
