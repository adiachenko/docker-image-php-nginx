#!/bin/bash
set -e

sed -i "s/pm.max_children = .*/pm.max_children = $PHP_FPM_MAX_CHILDREN/" /usr/local/etc/php-fpm.d/zz-docker.conf
sed -i "s/pm.start_servers = .*/pm.start_servers = $PHP_FPM_START_SERVERS/" /usr/local/etc/php-fpm.d/zz-docker.conf
sed -i "s/pm.min_spare_servers = .*/pm.min_spare_servers = $PHP_FPM_MIN_SPARE_SERVERS/" /usr/local/etc/php-fpm.d/zz-docker.conf
sed -i "s/pm.max_spare_servers = .*/pm.max_spare_servers = $PHP_FPM_MAX_SPARE_SERVERS/" /usr/local/etc/php-fpm.d/zz-docker.conf
sed -i "s/pm.max_requests = .*/pm.max_requests = $PHP_FPM_MAX_REQUESTS/" /usr/local/etc/php-fpm.d/zz-docker.conf

if [[ ! -z "$SSH_PRIVATE_KEY_BASE64" ]]
then
    echo "$SSH_PRIVATE_KEY_BASE64" | base64 -d > $HOME/.ssh/id_rsa
    chmod 400 $HOME/.ssh/id_rsa
    eval $(ssh-agent -s)
fi

exec "$@"