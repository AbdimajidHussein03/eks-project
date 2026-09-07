FROM nginx:alpine

RUN apk upgrade --no-cache

COPY index.html /usr/share/nginx/html/
COPY favicon.ico /usr/share/nginx/html/
COPY js /usr/share/nginx/html/js
COPY meta /usr/share/nginx/html/meta
COPY style /usr/share/nginx/html/style

EXPOSE 80
