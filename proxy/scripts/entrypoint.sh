#!/bin/bash

# add all configuration files of instances
echo "Configuring instances"
instances=$(echo $INSTANCES | tr "|" "\n")
for instance in $instances
do
    # split name and ips
    IFS=',' read -ra domainInfo <<< "${instance}"

    # check if it is https
    if [ ${domainInfo[0]} == "https" ]; then
        export HTTPS_ENABLED="true"
    else 
        export HTTPS_ENABLED="false"
    fi

    # read domain
    export DOMAIN=${domainInfo[1]}

    # read ip and port
    IFS=':' read -ra networkInfo <<< "${domainInfo[2]}"
    export IP=${networkInfo[0]}
    export PORT=${networkInfo[1]}

    echo "Configuring Domain: ${DOMAIN}, Ip: ${IP}, Port: ${PORT}"
    if [ "$HTTPS_ENABLED" = "true" ]; then
        envsubst "\${DOMAIN},\${IP},\${PORT},\${NGINX_CONF}" < "/conf/app_instance_https.conf" > "/etc/nginx/user.conf.d/app_${IP}.conf"

    else
        envsubst "\${DOMAIN},\${IP},\${PORT},\${NGINX_CONF}" < "/conf/app_instance_http.conf" > "/etc/nginx/user.conf.d/app_${IP}.conf"

    fi

    echo "Configuration /etc/nginx/user.conf.d/app_${IP}.conf:"
    cat "/etc/nginx/user.conf.d/app_${IP}.conf"
done

# copy certbot configuration if https is enabled
if [ "$HTTPS_ENABLED" = "true" ]; then
    cp -rf /conf/certbot.conf /etc/nginx/conf.d/certbot.conf
fi

# When we get killed, kill all our children
trap "exit" INT TERM
trap "kill 0" EXIT

# Source in util.sh so we can have our nice tools
. $(cd $(dirname $0); pwd)/util.sh

# first include any user configs if they've been mounted
template_user_configs

# Immediately run auto_enable_configs so that nginx is in a runnable state
auto_enable_configs

# Start up nginx, save PID so we can reload config inside of run_certbot.sh
nginx -g "daemon off;" &
NGINX_PID=$!

# Lastly, run startup scripts
for f in /scripts/startup/*.sh; do
    if [ -x "$f" ]; then
        echo "Running startup script $f"
        $f
    fi
done
echo "Done with startup"

# Instead of trying to run `cron` or something like that, just sleep and run `certbot`.
while [ true ]; do
    # Make sure we do not run container empty (without nginx process).
    # If nginx quit for whatever reason then stop the container.
    # Leave the restart decision to the container orchestration.
    if ! jobs | grep --quiet nginx ; then
        exit 1
    fi

    # Run certbot, tell nginx to reload its config
    if [ "$HTTPS_ENABLED" = "true" ]; then
        echo "Run certbot"
        /scripts/run_certbot.sh
        kill -HUP $NGINX_PID
    fi

    # Sleep for 1 week
    sleep 604810 &
    SLEEP_PID=$!

    # Wait for 1 week sleep or nginx
    wait -n "$SLEEP_PID" "$NGINX_PID"
done