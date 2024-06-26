FROM php:8.3-fpm-bookworm

LABEL maintainer="Alexander Diachenko"

ENV SSH_PRIVATE_KEY_BASE64 ${SSH_PRIVATE_KEY_BASE64:-}

# Define env variables for error reporting settings
ENV PHP_DISPLAY_ERRORS ${PHP_DISPLAY_ERRORS:-Off}
ENV PHP_DISPLAY_STARTUP_ERRORS ${PHP_DISPLAY_STARTUP_ERRORS:-Off}
ENV PHP_ERROR_REPORTING ${PHP_ERROR_REPORTING:-E_ALL & ~E_DEPRECATED & ~E_STRICT}

# Define env variables for memory settings
ENV PHP_MEMORY_LIMIT ${PHP_MEMORY_LIMIT:-128M}
ENV PHP_POST_MAX_SIZE ${PHP_POST_MAX_SIZE:-8M}
ENV PHP_UPLOAD_MAX_SIZE ${PHP_UPLOAD_MAX_SIZE:-2M}

# Define env variables for realpath cache settings
ENV PHP_REALPATH_CACHE_SIZE ${PHP_REALPATH_CACHE_SIZE:-4K}
ENV PHP_REALPATH_CACHE_TTL ${PHP_REALPATH_CACHE_TTL:-120}

# Define env variables for opcache settings
ENV PHP_OPCACHE_ENABLE_CLI ${PHP_OPCACHE_ENABLE_CLI:-0}
ENV PHP_OPCACHE_MEMORY_CONSUMPTION ${PHP_OPCACHE_MEMORY_CONSUMPTION:-128}
ENV PHP_OPCACHE_JIT_BUFFER_SIZE ${PHP_OPCACHE_JIT_BUFFER_SIZE:-0}
ENV PHP_OPCACHE_INTERNED_STRINGS_BUFFER ${PHP_OPCACHE_INTERNED_STRINGS_BUFFER:-8}
ENV PHP_OPCACHE_MAX_ACCELERATED_FILES ${PHP_OPCACHE_MAX_ACCELERATED_FILES:-10000}
ENV PHP_OPCACHE_MAX_WASTED_PERCENTAGE ${PHP_OPCACHE_MAX_WASTED_PERCENTAGE:-5}
ENV PHP_OPCACHE_VALIDATE_TIMESTAMPS ${PHP_OPCACHE_VALIDATE_TIMESTAMPS:-1}
ENV PHP_OPCACHE_SAVE_COMMENTS ${PHP_OPCACHE_SAVE_COMMENTS:-1}

# Define env variables for FPM settings
ENV PHP_FPM_MAX_CHILDREN ${PHP_FPM_MAX_CHILDREN:-20}
ENV PHP_FPM_START_SERVERS ${PHP_FPM_START_SERVERS:-2}
ENV PHP_FPM_MIN_SPARE_SERVERS ${PHP_FPM_MIN_SPARE_SERVERS:-1}
ENV PHP_FPM_MAX_SPARE_SERVERS ${PHP_FPM_MAX_SPARE_SERVERS:-3}
ENV PHP_FPM_MAX_REQUESTS ${PHP_FPM_MAX_REQUESTS:-1000}

# Define env variables for Xdebug settings
ENV PHP_XDEBUG_MODE ${PHP_XDEBUG_MODE:-off}
ENV PHP_XDEBUG_CLIENT_HOST ${PHP_XDEBUG_CLIENT_HOST:-host.docker.internal}

# Disable Composer memory limit to avoid potential issues with composer update
ENV COMPOSER_MEMORY_LIMIT -1

# Define env variables for Nginx configuration
ENV NGINX_SERVER_TYPE ${NGINX_SERVER_TYPE:-laravel}

# Install additional tools and PHP extensions
# Replace mysql-8.0 with mysql-8.4-lts in debconf-set-selections if you want 8.4
RUN apt-get update && apt-get install -y --no-install-recommends \
  git sqlite3 apache2-utils htop nano gettext-base lsb-release wget gnupg nginx supervisor \
  libpq-dev libjpeg62-turbo-dev libpng-dev libzip-dev libicu-dev g++ libfreetype6-dev libgmp-dev libxml2-dev \
  && curl https://repo.mysql.com/mysql-apt-config_0.8.30-1_all.deb --output mysql-apt-config.deb \
  && echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections \
  && DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config.deb \
  && install -d /usr/share/postgresql-common/pgdg \
  && curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  && sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' \
  && apt-get update \
  && apt-get install -y mysql-client postgresql-client-16 \
  && apt-get purge -y lsb-release wget gnupg \
  && apt-get install -y openssh-client \
  && mkdir -p $HOME/.ssh && chmod 700 $HOME/.ssh && echo "Host *\n\tStrictHostKeyChecking no\n\n" > $HOME/.ssh/config \
  && docker-php-ext-configure intl \
  && docker-php-ext-install intl \
  && docker-php-ext-install bcmath \
  && docker-php-ext-install pcntl \
  && docker-php-ext-install exif \
  && docker-php-ext-install opcache \
  && docker-php-ext-install pdo_mysql \
  && docker-php-ext-install pdo_pgsql \
  && docker-php-ext-install zip \
  && docker-php-ext-configure gd --with-jpeg --with-freetype \
  && docker-php-ext-install gd \
  && docker-php-ext-install sockets \
  && docker-php-ext-install gmp \
  && yes '' | pecl install redis-6.0.2 \
  && docker-php-ext-enable redis \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && echo "daemon off;" >> /etc/nginx/nginx.conf

# Install Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

# Install Xdebug
RUN yes '' | pecl install xdebug-3.3.2 && docker-php-ext-enable xdebug

# Install Blackfire
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
  && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
  && mkdir -p /tmp/blackfire \
  && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
  && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get ('extension_dir');")/blackfire.so \
  && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
  && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz

# Install NodeJS
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g yarn \
  && npm cache clean --force \
  && apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy over PHP Configuration.
#   Development defaults: https://github.com/php/php-src/blob/master/php.ini-development
#   Producton defaults: https://github.com/php/php-src/blob/master/php.ini-production
COPY php/php.ini $PHP_INI_DIR/php.ini
COPY php/opcache.ini $PHP_INI_DIR/conf.d/
COPY php/xdebug.ini $PHP_INI_DIR/conf.d/
COPY php/fpm.conf /usr/local/etc/php-fpm.d/zz-docker.conf

# Override default entrypoint to enable editing FPM config with env variables
COPY entrypoint.sh /usr/local/bin/docker-php-entrypoint
RUN chmod +x /usr/local/bin/docker-php-entrypoint

# Copy over Nginx configuration
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/

# Copy over Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Ensure nginx is properly passing to php-fpm and fpm is responding
HEALTHCHECK --start-period=5s --timeout=3s --interval=1m \
  CMD curl -f http://localhost/php-fpm-ping || exit 1

WORKDIR /opt/project
EXPOSE 80

CMD envsubst < /etc/nginx/conf.d/default.template > /etc/nginx/sites-available/default \
  && /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
