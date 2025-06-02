FROM php:8.4-fpm

ARG SYMFONY_VERSION=v2.7.0

RUN apt-get update && apt-get install -y \
    git unzip zip libicu-dev libzip-dev libpq-dev libonig-dev \
    && docker-php-ext-install intl pdo pdo_mysql opcache zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /tmp
RUN rm -rf /var/www && \
    git clone --branch ${SYMFONY_VERSION} https://github.com/symfony/demo.git /var/www
WORKDIR /var/www


# Install dependencies
RUN composer install --no-interaction

# Copy application files
RUN chown -R www-data:www-data /var/www

EXPOSE 9000
CMD ["php-fpm"]
