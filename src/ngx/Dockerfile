FROM nginx:alpine AS build

RUN mkdir -p /var/log/nginx/logs
RUN mkdir -p /var/www/html/acme-challenge
RUN mkdir -p /etc/letsencrypt
RUN mkdir -p /var/www/certbot
RUN rm /etc/nginx/conf.d/*

EXPOSE 80
EXPOSE 443

CMD [ "nginx", "-g", "daemon off;" ]