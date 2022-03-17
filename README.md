# Docker PHP-FPM with Nginx

- [Docker PHP-FPM with Nginx](#docker-php-fpm-with-nginx)
  - [Introduction](#introduction)
  - [Supported PHP Versions](#supported-php-versions)
  - [Usage](#usage)
    - [Apple Silicon](#apple-silicon)
    - [Production Usage](#production-usage)
    - [Cron Schedule](#cron-schedule)
    - [Laravel Octane](#laravel-octane)
  - [Configuration](#configuration)
  - [Creating Images](#creating-images)

## Introduction

This image is based on official PHP-FPM Docker image.

Additional software:

- Nginx (with pre-made configs for Laravel, Laravel Octane, Symfony and Wordpress)
- SQLite
- Composer
- Xdebug
- NodeJS
- Blackfire
- Command-line clients for MySQL and PostgreSQL to support [migration squashing](https://laravel.com/docs/8.x/migrations#squashing-migrations)
- htop
- GNU nano

Compiled in modules (according to `php -m`):

```
bcmath
blackfire
Core
ctype
curl
date
dom
exif
fileinfo
filter
ftp
gd
hash
iconv
intl
json
libxml
mbstring
mysqlnd
openssl
pcntl
pcre
PDO
pdo_mysql
pdo_pgsql
pdo_sqlite
Phar
posix
readline
redis
Reflection
session
SimpleXML
sockets
sodium
SPL
sqlite3
standard
tokenizer
xdebug
xml
xmlreader
xmlwriter
Zend OPcache
zip
zlib
```

## Supported PHP Versions

- 7.4 (use `adiachenko/php-nginx:7.4`)
- 8.0 (use `adiachenko/php-nginx:8.0`)
- 8.1 (use `adiachenko/php-nginx:8.1`)

## Usage

Example `docker-compose.yml` file for Laravel project:

```yml
version: '3.8'

services:
  app:
    image: adiachenko/php-nginx
    environment:
      - NGINX_SERVER_TYPE=laravel
    ports:
      - 8000:80
    volumes:
      - ./:/opt/project:cached
```

You can set Nginx config suited for your framework using `NGINX_SERVER_TYPE` env variable (container restart required):

- laravel
- octane
- symfony
- wordpress

### Apple Silicon

This image doesn't **natively** support Apple Silicon, because MySQL doesn't provide [ARM64 version](https://www.mysql.com/support/supportedplatforms/database.html) for Debian which we need in order to install a command-line client.

However, you can add `--platform linux/amd64` to run this image under emulation.

### Production Usage

If you don't mind the size of the image, it's perfectly suitable for production usage. Just enable opcache and adjust other settings using env variables as described in [configuration section](#configuration).

### Cron Schedule

You don't need cron for scheduled tasks in Docker. There are cleaner alternatives for containers like [Ofelia](https://github.com/mcuadros/ofelia). Another option is to run command like [Laravel Cronless Schedule](https://github.com/spatie/laravel-cronless-schedule) in a separate container.

Here is an example using Ofelia with a Laravel app:

```yml
version: '3.8'

services:
  app:
    image: adiachenko/php-nginx
    environment:
      - NGINX_SERVER_TYPE=laravel
    ports:
      - 8000:80
    volumes:
      - ./:/opt/project:cached
    labels:
      # See https://github.com/mcuadros/ofelia#docker-labels-configurations
      ofelia.enabled: 'true'
      ofelia.job-exec.schedule.schedule: '@every 60s'
      ofelia.job-exec.schedule.command: 'php artisan schedule:run'

  ofelia:
    depends_on:
      - app
    image: mcuadros/ofelia:v0.3.6
    command: daemon --docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

### Laravel Octane

> This image only supports Roadrunner server.

Octane runs as PHP CLI application so we must adjust `docker-compose.yml` file accordingly:

```yml
version: '3.8'

services:
  app:
    image: adiachenko/php-nginx
    # Run the image without PHP-FPM
    command: >
      bash -c "envsubst < /etc/nginx/conf.d/default.template > /etc/nginx/sites-available/default && nginx"
    environment:
      - NGINX_SERVER_TYPE=octane
      - PHP_OPCACHE_ENABLE_CLI=1
    ports:
      - 8000:80
    volumes:
      - ./:/opt/project:cached
```

## Configuration

This image ships with the default `php.ini` for production environments.

Default Opcache settings are adjusted with the following values to improve DX:

> Make sure you disable `opcache.validate_timestamps` for deployed version of your image.

```ini
; If enabled, OPcache will check for updated scripts every opcache.revalidate_freq
; seconds. When this directive is disabled, you must reset OPcache manually
; by running 'kill -USR2 1' inside the container
opcache.validate_timestamps=1

; How often to check script timestamps for updates, in seconds. 0 will result
; in OPcache checking for updates on every request. This configuration
; directive is ignored if opcache.validate_timestamps is disabled.
opcache.revalidate_freq=0
```

You can change configuration using the following environment variables:

| Envitonment Variable                | Default                           |
| ----------------------------------- | --------------------------------- |
| PHP_DISPLAY_ERRORS                  | Off                               |
| PHP_DISPLAY_STARTUP_ERRORS          | Off                               |
| PHP_ERROR_REPORTING                 | E_ALL & ~E_DEPRECATED & ~E_STRICT |
| PHP_MEMORY_LIMIT                    | 128M                              |
| PHP_POST_MAX_SIZE                   | 8M                                |
| PHP_UPLOAD_MAX_SIZE                 | 2M                                |
| PHP_REALPATH_CACHE_SIZE             | 4K                                |
| PHP_REALPATH_CACHE_TTL              | 120                               |
| PHP_OPCACHE_ENABLE_CLI              | 0                                 |
| PHP_OPCACHE_MEMORY_CONSUMPTION      | 128                               |
| PHP_OPCACHE_JIT_BUFFER_SIZE         | 0                                 |
| PHP_OPCACHE_INTERNED_STRINGS_BUFFER | 8                                 |
| PHP_OPCACHE_MAX_ACCELERATED_FILES   | 10000                             |
| PHP_OPCACHE_MAX_WASTED_PERCENTAGE   | 5                                 |
| PHP_OPCACHE_VALIDATE_TIMESTAMPS     | 1                                 |
| PHP_OPCACHE_SAVE_COMMENTS           | 1                                 |
| PHP_XDEBUG_MODE                     | off                               |
| PHP_XDEBUG_CLIENT_HOST              | host.docker.internal              |

You may also tweak process manager settings:

| Envitonment Variable                | Default                           |
| ----------------------------------- | --------------------------------- |
| PHP_FPM_MAX_CHILDREN                | 20                                |
| PHP_FPM_START_SERVERS               | 2                                 |
| PHP_FPM_MIN_SPARE_SERVERS           | 1                                 |
| PHP_FPM_MAX_SPARE_SERVERS           | 3                                 |
| PHP_FPM_MAX_REQUESTS                | 1000                              |

## Creating Images

Build images:

```sh
docker build --no-cache -t adiachenko/php-nginx:8.0 .
docker build -t adiachenko/php-nginx:latest .
```

Push images to Docker Hub:

```
docker push adiachenko/php-nginx:8.0
docker push adiachenko/php-nginx:latest
```
