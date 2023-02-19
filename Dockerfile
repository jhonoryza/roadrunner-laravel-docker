FROM ghcr.io/roadrunner-server/roadrunner:2.9.2 AS roadrunner
FROM php:8.1-cli-alpine3.16 as php-base
    RUN apk add --no-cache $PHPIZE_DEPS autoconf libzip-dev zip unzip wget curl && \
        docker-php-ext-install bcmath ctype pdo pdo_mysql pcntl sockets zip

    RUN pecl install redis && docker-php-ext-enable redis

    COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

    ENV NODE_PATH "/home/www-data/.npm-global/lib/node_modules"
    RUN apk add --no-cache nodejs npm && \
        mkdir "/home/www-data/.npm-global/" && \
        npm config set prefix "/home/www-data/.npm-global/" && \
        npm install -g chokidar

FROM php-base as app
    USER www-data
    WORKDIR /home/app
    ARG APP_DIR
    ARG BUILD_DIR
    ARG ROADRUNNER_MAX_REQUESTS
    ARG ROADRUNNER_WATCH
    ARG ROADRUNNER_WORKERS

    # setup app
    COPY --chown=www-data:www-data $APP_DIR /home/app/
    RUN rm .env
    RUN rm .rr.yaml
    RUN rm rr

    USER root
    COPY --from=roadrunner /usr/bin/rr /home/app/rr
    RUN chown www-data:www-data /home/app/rr

    USER www-data
    RUN composer install --no-dev

    # Allow the user to specify RoadRunner options via ENV variables.
    ENV ROADRUNNER_MAX_REQUESTS $ROADRUNNER_MAX_REQUESTS
    ENV ROADRUNNER_WATCH $ROADRUNNER_WATCH
    ENV ROADRUNNER_WORKERS $ROADRUNNER_WORKERS

    # Run RoadRunner
    CMD if [[ -z $ROADRUNNER_WATCH ]] ; then \
        php artisan octane:start --server="roadrunner" --port=8080 --host="0.0.0.0" --workers=${ROADRUNNER_WORKERS} --max-requests=${ROADRUNNER_MAX_REQUESTS} ; \
    else \
        php artisan octane:start --server="roadrunner" --port=8080 --host="0.0.0.0" --workers=${ROADRUNNER_WORKERS} --max-requests=${ROADRUNNER_MAX_REQUESTS} --watch ; \
    fi

    # Check the health status using the Octane status command.
    HEALTHCHECK CMD php artisan octane:status --server="roadrunner"

    EXPOSE 8080