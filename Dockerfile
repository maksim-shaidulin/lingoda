FROM php:8.4-fpm

RUN apt-get update && apt-get install -y \
    git unzip zip libicu-dev libzip-dev libpq-dev libonig-dev \
    && docker-php-ext-install intl pdo pdo_mysql opcache zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /tmp
# RUN git clone https://github.com/symfony/demo.git /tmp/demo && mv /tmp/demo /var/www
RUN rm -rf /var/www && git clone https://github.com/symfony/demo.git /var/www
WORKDIR /var/www


# Install dependencies
RUN composer install --no-interaction

# Copy application files
RUN chown -R www-data:www-data /var/www

EXPOSE 9000
CMD ["php-fpm"]
