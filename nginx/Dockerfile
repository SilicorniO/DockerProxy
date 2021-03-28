#staticfloat/nginx-certbot
FROM nginx

RUN apt update && apt install -y certbot

# Copy in scripts for certbot
COPY ./scripts/*.sh /scripts/
RUN chmod +x /scripts/*.sh

# Add /scripts/startup directory to source more startup scripts
RUN mkdir -p /scripts/startup

# Copy in default nginx configuration (which just forwards ACME requests to
# certbot, or redirects to HTTPS, but has no HTTPS configurations by default).
RUN rm -f /etc/nginx/conf.d/*

# copy template files
COPY ./conf/*.conf /conf/

# generate directory where to add configuration files
RUN mkdir /etc/nginx/user.conf.d/

# generate directory for nginx data
RUN mkdir -p /data/www/

ENTRYPOINT []
CMD ["/bin/bash", "/scripts/entrypoint.sh"]