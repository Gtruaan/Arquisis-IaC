#!/bin/bash


# === Instala Nginx ===
echo " ======* Instalando Nginx"  
sudo apt update -y  
DEBIAN_FRONTEND=noninteractive sudo apt install nginx -y  

# === Crea archivo de config de Nginx ===
echo " ======* Creando archivo de configuracion de Nginx"  
sudo tee /etc/nginx/nginx.conf <<EOF
worker_processes 1;

user nobody nogroup;
# 'user nobody nobody;' for systems with 'nobody' as a group instead
error_log  /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
  worker_connections 1024; # increase if you have lots of clients
  accept_mutex off; # set to 'on' if nginx worker_processes > 1
  # 'use epoll;' to enable for Linux 2.6+
  # 'use kqueue;' to enable for FreeBSD, OSX
}

http {
  include mime.types;
  # fallback in case we can't determine a type
  default_type application/octet-stream;
  access_log /var/log/nginx/access.log combined;
  sendfile on;

  log_format upstreamlog '\$server_name to: \$upstream_addr [\$request]'
  'upstream_response_time \$upstream_response_time'
  'msec \$msec request_time \$request_time';

  upstream app_server {
    # fail_timeout=0 means we always retry an upstream even if it failed
    # to return a good HTTP response

    # for UNIX domain socket setups
    server unix:/tmp/gunicorn.sock fail_timeout=0;

    # for a TCP configuration
    server localhost:8000 fail_timeout=0;
    server localhost:8001 fail_timeout=0;
    # server localhost:8002 fail_timeout=0;
  }

  server {
    # if no Host match, close the connection to prevent host spoofing
    listen 80 default_server;
    return 444;
  }

  server {
    # use 'listen 80 deferred;' for Linux
    # use 'listen 80 accept_filter=httpready;' for FreeBSD
    client_max_body_size 4G;

    # set the correct host(s) for your site
    server_name 3.21.140.164 api.arkairlines.me;
    # example.com www.example.com;

    keepalive_timeout 5;

    # see logs
    access_log /var/log/nginx/access.log.2 upstreamlog;

    # path for static files
    root /var/lib/docker/volumes/e0-iic2173-2024-1-bmarink512_static/_data;

    location / {
      # checks for static file, if not found proxy to app
      try_files \$uri @proxy_to_app;
    }

    location @proxy_to_app {
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header Host \$http_host;
      # we don't want nginx trying to do something clever with
      # redirects, we set the Host: header above already.
      proxy_redirect off;
      proxy_pass http://app_server;
    }

   # error_page 500 502 503 504 /500.html;
   # location = /500.html {
   #   root /path/to/app/current/public;
   # }

 

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/api.arkairlines.me/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/api.arkairlines.me/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot


}


  server {
    if (\$host = api.arkairlines.me) {
        return 301 https://\$host\$request_uri;
    } # managed by Certbot

    listen 80;
    return 404; # managed by Certbot


}}
EOF

# === Instala Docker y Docker Compose ===
echo " ======* Instalando Docker y Docker Compose"  

sudo apt update -y
sudo apt upgrade -y

# Install Docker APT Repository
sudo apt install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
"deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update -y
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Start Docker
sudo service docker start

# === Clona el repositorio de la app ===
echo " ======* Clonando repositorio de la app"  
personal_access_token="PAT AQUI"
sudo git clone https://<personal_access_token>:x-oauth-basic@github.com/BMarink512/Arquisis-Back.git
cd Arquisis-Back 

# === Crea archivo .env ===
echo " ======* Creando archivo .env"  
touch .env  
echo "POSTGRES_USER=postgres" >> .env
echo "POSTGRES_PASSWORD=postgres" >> .env
echo "POSTGRES_DB=postgres" >> .env

touch api/.env  
echo "POSTGRES_NAME=postgres" >> api/.env
echo "POSTGRES_USER=postgres" >> api/.env
echo "POSTGRES_PASSWORD=postgres" >> api/.env
echo "POSTGRES_HOST=db" >> api/.env
echo "POSTGRES_PORT=5432" >> api/.env
echo "SECRET_KEY=umP9dDlWBaTqoj8VbpJFMcz2gOIOt6UkATyKsAsb+EM=" >> api/.env
echo "DEBUG=False" >> api/.env
echo "GDAL_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/libgdal.so.32" >> api/.env
echo "ALLOWED_HOSTS=*" >> api/.env
echo "TICKETS_API_URL=http://broker:5050/" >> api/.env
echo "TEST_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IlVUTHNFYW1ObG9rVzBNdnk1Tm0tcyJ9.eyJpc3MiOiJodHRwczovL2Rldi1oYmplMXQ1ZXM1a20xbGJzLnVzLmF1dGgwLmNvbS8iLCJzdWIiOiJhdXRoMHw2NjIzNDkwZmQxNDRkMGNiYWEwOWI4OTQiLCJhdWQiOlsiaHR0cHM6Ly9kZXYtaGJqZTF0NWVzNWttMWxicy51cy5hdXRoMC5jb20vYXBpL3YyLyIsImh0dHBzOi8vZGV2LWhiamUxdDVlczVrbTFsYnMudXMuYXV0aDAuY29tL3VzZXJpbmZvIl0sImlhdCI6MTcxMzczMTA3NCwiZXhwIjoxNzEzODE3NDc0LCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIHBob25lIHJlYWQ6Y3VycmVudF91c2VyIHVwZGF0ZTpjdXJyZW50X3VzZXJfbWV0YWRhdGEiLCJhenAiOiJLZm1hbkJDeGdlUUpsZVlPckFNeTVxdEhNMHZaYU1XSiJ9.CFQjSX9U441J7N9bReEAVd36naxIfTphskdq7UfhRGjsBw-nZQZKhEUP05aHnqa4enAYz9Xemip9k_jgkgenQi3mMjzc9gBzBw3bl3ieEM2xFfMGGdtkDH5i_w-X_MMpOQdY76xaW3hi0i6l2AsWo0-L5Dmu0mNERWbP3vRr3DqQ10szv--eXh4cN0g17_BLKBRI0c_lSgsPH7yPhIeDcGhj462Q4rUP2OIud47iGlXneXUZul1bfkjrOkwN9OHWruRdcMVI1Nmwt0-3CwkelQklupAxWoDJTrT3vtcYS6eFw7yAA_ScYYWPmUkeAY8RfNZTOO7w9lfusx87d_Rl3g" >> api/.env
echo "AUTH0_DOMAIN=DOMINIO AUTH0 AQUI" >> api/.env
echo "AUTH0_AUDIENCE=AUDIENCE AUTH0 AQUI" >> api/.env
echo "LAMBDA_API_URL=URL DE LAMBDA LEVANTADA AQUI" >> api/.env
echo "ENVIRONMENT=dev" >> api/.env
echo "RETURN_URL=http://arkairlines.me/pay" >> api/.env
echo "WORKER_API_URL=http://producer:8080/" >> api/.env

touch broker/.env  
echo "HOST=broker.iic2173.org" >> broker/.env
echo "PORT=9000" >> broker/.env
echo "USER_MQTT=students" >> broker/.env
echo "PASSWORD=iic2173-2024-1-students" >> broker/.env
echo "URL_API=http://web" >> broker/.env
echo "PORT_API=8000" >> broker/.env
echo "CHANNEL_INFO=flights/info" >> broker/.env
echo "CHANNEL_REQUESTS=flights/requests" >> broker/.env
echo "CHANNEL_VALIDATION=flights/validation" >> broker/.env
echo "REQUEST_CREATE=flights/create" >> broker/.env
echo "REQUEST_BUY=flights/buy" >> broker/.env
echo "REQUEST_VALIDATE=flights/validation" >> broker/.env
echo "TOKEN=COLOCAR TOKEN AQUÍ" >> broker/.env

touch workers/.env  
echo "CELERY_BROKER_URL=redis://redis:6379/0" >> workers/.env
echo "CELERY_RESULT_BACKEND=redis://redis:6379/0" >> workers/.env
echo "DATABASE_URL=postgresql://postgres:postgres@db:5432/postgres" >> workers/.env


# === Inicia Nginx ===
echo " ======* Iniciando Nginx"  
sudo nginx

# === Instala Certbot ===
echo " ======* Instalando Certbot"  
DEBIAN_FRONTEND=noninteractive sudo apt install certbot python3-certbot-nginx -y  
sudo certbot --nginx  


