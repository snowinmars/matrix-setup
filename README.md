# How to self-host Matrix and Element docker compose

    Based on https://cyberhost.uk/element-matrix-setup/#installmatrixandelement - I extend with nginx section.

This is a complete guide on setting up Matrix (Synapse) and Element on a fresh linux server using docker.

## What is Matrix?

Matrix is an open standard and communication protocol for real-time communication. It aims to make real-time communication work seamlessly between different service providers, just like standard Simple Mail Transfer Protocol email does now for store-and-forward email service, by allowing users with accounts at one communications service provider to communicate with users of a different service provider via online chat, voice over IP, and video-telephony. Such protocols have been around before such as XMPP but Matrix is not based on that or another communication protocol. From a technical perspective, it is an application layer communication protocol for federated real-time communication. It provides HTTP APIs and open source reference implementations for securely distributing and persisting messages in JSON format over an open federation of servers. It can integrate with standard web services via WebRTC, facilitating browser-to-browser applications. Wikipedia

    If you do know how to bind fqdn to docker compose - do it. If you don't - use ip
    In this guide use the following substitution:
    - $USERNAME: snowinmars
    - ###
    - # dns
    - $NGX_DOMAIN:              10.10.10.100 or example.org
    - $POSTGRES_DOMAIN:         10.10.10.2   or postgres.example.org
    - $SYNAPSE_DOMAIN:          10.10.10.3   or synapse.example.org
    - $SYNAPSE_PORT:            8080
    - $ELEMENTS_DOMAIN:         10.10.10.4   or elements.example.org
    - $ELEMENTS_PORT:           80
    - $MAUTRIX_TELEGRAM_DOMAIN: 10.10.10.11   or mautrix-telegram.example.org
    - $MAUTRIX_DISCORD_DOMAIN: 10.10.10.12   or mautrix-discord.example.org
    - ###
    - # postgres settings
    - $POSTGRES_DB:          synapse
    - $POSTGRES_USER:        synapse
    - $POSTGRES_PASSWORD:    kljfdgkjbflkbjnlkdjfhg
    - $POSTGRES_INITDB_ARGS: --encoding=UTF-8 --lc-collate=C --lc-ctype=C
    - ###
    - # mautrix telegram settings
    - $BOT_USERNAME: telegrambot
    - $TELEGRAM_API_ID:   11111           # from https://my.telegram.org/apps
    - $TELEGRAM_API_HASH: 22222           # from https://my.telegram.org/apps
    - $TELEGRAM_BOT_ACCESS_KEY: 3333:aaaa # from @BotFather

Every variables between files should match each other. It's good idea to add `.env` file and setup templating, but I will skip it in this guide for now. Replace it manually.

    Friendly advice: almost all containers will restrict you to read or write to it's config files. So run your IDE using sudo.

## Domain setup

    If you run the system locally, skip this step.

1. Register domain `$NGX_DOMAIN`
2. Create a virtual machine with public ip
3. Add three DNS 'A/AAAA' records:
   - `$NGX_DOMAIN -> public ip`
   - `$MATRIX_DOMAIN -> public ip`
   - `$ELEMENTS_DOMAIN -> public ip`

## Server Setup

    If you run the system locally, skip this step.

`sudo nano /etc/ssh/sshd_config`

1. Change SSH Port to something from `30000` to `50000`

   This is security though obsucurity which is not ideal but port `22` just gets abused by bots.
2. Disable ssh by password
3. Setup SSH Keys **with** passphrase
4. Restart SSH: `sudo systemctl restart sshd`
5. Optional: install `fail2ban`

### Optional: install UFW Firewall

    If you run the system locally, skip this step.

1. Install `ufw`
2. Replace SSH-PORT to your SSH port: sudo ufw allow <SSH-PORT>/tcp
3. Allow HTTP/s traffic:

   `sudo ufw allow 80/tcp`

   `sudo ufw allow 443/tcp`

4. Enable Firewall: `sudo ufw enable`

### Setup a sudo user at the host machine

    If you run the system locally, skip this step.

1. `adduser <USERNAME>`
2. Add user to sudoers `sudo adduser <USERNAME> sudo`
3. Login as the new user `su - <USERNAME>`

### Install Docker and Docker Compose

See docker docs.

## Install Matrix and Element

Here and below you will use files inside some directory `.` The result tree will look something like:
```
.
├── crt/
│   └── letsencrypt/
│       └── live/
│           └── $NGX_DOMAIN/
│               ├── cert.pem
│               ├── chain.pem
│               ├── fullchain.pem
│               ├── privkey.pem
│               └── README
├── element/
│   └── config.json
├── ngx/
│   ├── acme-challenge/
│   │   ├── acmefile1
│   │   └── acmefile2
│   ├── default.conf
│   ├── Dockerfile
│   ├── https.conf
│   └── cors.conf
├── postgres/
│   └── Dockerfile
├── synapse/
│   └── homeserver.yaml
└── docker-compose.yaml
```

To generate this tree (without files that will be generatel later), use the following commands:

- `mkdir -p ./crt/letsencrypt/ ./element ./ngx/acme-challenge ./postgres ./synapse`
- `touch ./docker-compose.yaml ./element/config.json ./ngx/default.conf ./ngx/cors.conf ./ngx/https.conf ./ngx/Dockerfile ./postgres/Dockerfile`

### Run empty servers

1. Create docker bridge network, this is so all the system services can be on their own isolated network:
   `docker network create --driver=bridge --subnet=10.10.10.0/24 --gateway=10.10.10.1 matrix_net`

   Beware: `docker compose down` removes the network. You can't just `docker compose up` it again: create the network and then run the containers.

3. Use the following template:

```yaml
# ./docker-compose.yaml
version: '2.3'
services:
  matrix-postgres:
    container_name: matrix-postgres
    image: snowinmars/matrix-postgres:1.0.0
    build:
      context: ./postgres
      dockerfile: ./Dockerfile
    # restart: unless-stopped
    volumes:
      - ./postgres/postgresdata:/var/lib/postgresql/data
    # These will be used in homeserver.yaml later on
    environment:
      - POSTGRES_DB=$POSTGRES_DB
      - POSTGRES_USER=$POSTGRES_USER
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
      - POSTGRES_INITDB_ARGS=$POSTGRES_INITDB_ARGS
    networks:
      default:
        ipv4_address: $POSTGRES_DOMAIN
    
  matrix-synapse:
    container_name: matrix-synapse
    image: matrixdotorg/synapse:v1.77.0
    build:
      context: ./synapse
    depends_on:
      - matrix-postgres
    # restart: unless-stopped
    volumes:
      - ./synapse:/data
    networks:
      default:
        ipv4_address: $SYNAPSE_DOMAIN

  matrix-element:
    container_name: matrix-element
    image: vectorim/element-web:v1.11.23
    build:
      context: ./element
    depends_on:
      - matrix-synapse
    # restart: unless-stopped
    volumes:
      - ./element/config.json:/app/config.json
    networks:
      default:
        ipv4_address: $ELEMENTS_DOMAIN

networks:
  default:
    name: matrix_net
```

3. It should work fine with default postgres image, but postgres could complain about UTF locale, so:

```dockerfile
# ./postgres/Dockerfile
FROM postgres
RUN localedef -i C -c -f UTF-8 -A /usr/share/locale/locale.alias C
ENV LANG C
```

4. Create Element Config

Default element config `./element/config.json` has `integrations_ui_url`/`integrations_rest_url`/`integrations_widgets_urls` properties pointing to `https://scalar.vector.im`. This is integration service settings: this service act as a proxy between mautrix bots and matrix itself.

- If these settings are set, you will be able to click 'Room -> Room info -> Add widgets, bridges & bots -> Invite'
- If these settings are null, the 'Add widgets, bridges & bots' button will be disabled

The integration server (like Dimension) is a legacy: it's possible to use direct connection between mautrix bots and matrix. So sel them to null as the following and use 'Room -> Invite' button to invite mautrix bots into matrix room:

```json
# ./element/config.json
{
  // add custom homeserver here, see next step
  "brand": "Element",
  "integrations_ui_url": null,
  "integrations_rest_url": null,
  "integrations_widgets_urls": null,
  "hosting_signup_link": "https://element.io/matrix-services?utm_source=element-web&utm_medium=web",
  "bug_report_endpoint_url": "https://element.io/bugreports/submit",
  "uisi_autorageshake_app": "element-auto-uisi",
  "showLabsSettings": true,
  "piwik": {
    "url": "https://piwik.riot.im/",
    "siteId": 1,
    "policyUrl": "https://element.io/cookie-policy"
  },
  "roomDirectory": {
    "servers": [
      "matrix.org",
      "gitter.im",
      "libera.chat"
    ]
  },
  "enable_presence_by_hs_url": {
    "https://matrix.org": false,
    "https://matrix-client.matrix.org": false
  },
  "terms_and_conditions_links": [
    {
      "url": "https://element.io/privacy",
      "text": "Privacy Policy"
    },
    {
      "url": "https://element.io/cookie-policy",
      "text": "Cookie Policy"
    }
  ],
  "hostSignup": {
    "brand": "Element Home",
    "cookiePolicyUrl": "https://element.io/cookie-policy",
    "domains": [
      "matrix.org"
    ],
    "privacyPolicyUrl": "https://element.io/privacy",
    "termsOfServiceUrl": "https://element.io/terms-of-service",
    "url": "https://ems.element.io/element-home/in-app-loader"
  },
  "sentry": {
    "dsn": "https://029a0eb289f942508ae0fb17935bd8c5@sentry.matrix.org/6",
    "environment": "develop"
  },
  "posthog": {
    "projectApiKey": "phc_Jzsm6DTm6V2705zeU5dcNvQDlonOR68XvX2sh1sEOHO",
    "apiHost": "https://posthog.element.io"
  },
  "features": {
    "feature_spotlight": true
  },
  "map_style_url": "https://api.maptiler.com/maps/streets/style.json?key=fU3vlMsMn4Jb6dnEIFsx"
}
```

5. Add our custom homeserver to the top of `./element/config.json`:

```json
# ./element/config.json
{
   "default_server_config": {
      "m.homeserver": {
         "base_url": "http(s)://$NGX_DOMAIN",
         "server_name": "$NGX_DOMAIN"
      },
      "m.identity_server": {
         "base_url": "https://vector.im"
      }
   },
   // ...
}
```

6. Generate Synapse config:
```bash
docker run -it --rm \
  -v "$PWD/synapse:/data" \
  -e SYNAPSE_SERVER_NAME=$SYNAPSE_DOMAIN \
  -e SYNAPSE_REPORT_STATS=yes \
  matrixdotorg/synapse:v1.77.0 generate
```

7. Comment out sqlite database (as we have setup postgres to replace this) in `./synapse/homeserver.yaml`:

```yaml
# ./synapse/homeserver.yaml
#database:
#  name: sqlite3
#  args:
#    database: /data/homeserver.db
```

8. Add the Postgres config to `./synapse/homeserver.yaml`
```yaml
# ./synapse/homeserver.yaml
database:
  name: psycopg2
  args:
    database: $POSTGRES_DB
    user: $POSTGRES_USER
    password: $POSTGRES_PASSWORD
    host: $POSTGRES_DOMAIN
    cp_min: 5
    cp_max: 10
```

9. Run `docker compose up` - should not throw any errors. Wait until the system stop writing to log.

### Create New Users

Now matrix and element systems are created, but inaccessible from outside. You should create admin user for the future usage. During compose is up:

1. Access docker shell: `docker exec -it matrix-synapse bash`
2. `register_new_matrix_user -c /data/homeserver.yaml http://localhost:8008` with $USERNAME username
3. Follow the on screen prompts (make admin)
4. Enter `exit` to leave the container's shell

To allow anyone to register an account set `'enable_registration'` to true in the `homeserver.yaml`. This is **NOT** recommended.

## Install Reverse Proxy (Nginx or Caddy)

Use only one: nginx or caddy. This step is required no matter do you use local dev or production deployment.

### Nginx

1. Setup `./ngx/Dockerfile`:
```dockerfile
# ./ngx/Dockerfile
FROM nginx:alpine AS build

RUN mkdir -p /var/log/nginx/logs
RUN mkdir -p /var/www/html/acme-challenge
RUN mkdir -p /etc/letsencrypt
RUN mkdir -p /var/www/certbot
RUN rm /etc/nginx/conf.d/*

EXPOSE 80
EXPOSE 443

CMD [ "nginx", "-g", "daemon off;" ]
```

2. Create `./ngx/default.conf`:

```nginx
# ./ngx/default.conf
server {
    listen 80;
    server_name $NGX_DOMAIN www.$NGX_DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        allow all;
        default_type "text/plain";
        alias /var/www/html/acme-challenge/;
        break;
    }

    return 200 'hello'; # beware: this line will override acme challenge flow. Drop it, if you need to test acme
}
```

3. Add nginx to `./docker-compose.yaml`:
```yaml
# ./docker-compose.yaml
matrix-ngx:
   container_name: matrix-ngx
   image: snowinmars/matrix-ngx:1.0.0
   # restart: unless-stopped
   build:
      context: ./ngx
      dockerfile: ./Dockerfile
   ports:
      - '80:80'
      - '443:443'
   volumes:
      - ./ngx/default.conf:/etc/nginx/conf.d/default.conf
      - ./ngx/https.conf:/etc/nginx/https.conf
      - ./ngx/cors.conf:/etc/nginx/cors.conf
      - ./ngx/acme-challenge:/var/www/html/acme-challenge
      - ./crt/letsencrypt:/etc/letsencrypt
   networks:
      default:
        ipv4_address: $NGX_DOMAIN
```

4. Run `docker compose up` and check that `http://$NGX_DOMAIN` returns 'hello';

### Without ssl (local dev usage only)

Replace `./ngx/default.conf` with the following

```nginx
# ./ngx/default.conf
server {
    listen 80;
    server_name $NGX_DOMAIN;

    location /_matrix {
        proxy_pass http://$SYNAPSE_DOMAIN:8008; # beware of port!
    }

    location /_synapse/client {
        proxy_pass http://$SYNAPSE_DOMAIN:8008; # beware of port!
    }

    location / {
        proxy_pass http://$ELEMENTS_DOMAIN:$ELEMENTS_PORT;
    }
}

server {
    listen 443;
    server_name $NGX_DOMAIN;

    location /_matrix {
        proxy_pass http://$SYNAPSE_DOMAIN:8008; # beware of port!
    }

    location /_synapse/client {
        proxy_pass http://$SYNAPSE_DOMAIN:8008; # beware of port!
    }

    location / {
        proxy_pass http://$ELEMENTS_DOMAIN:$ELEMENTS_PORT;
    }
}
```

### Add ssl (production usage)

1. Install and run `certbot` to any pc, it does not have to be your production host: `sudo certbot certonly --manual`. If you want to clear previous certificates, use `sudo certbot delete`

2. Ask `certbot` to generate certificates for `*.$NGX_DOMAIN $NGX_DOMAIN`. It will produce acme files and/or DNS TXT records, so you have to

3. Add acme files to `./ngx/acme-challenge` directory, add DNS TXT records to DNS server and follow the rest certbot steps

4. Check that new certificates appears (see certbot output, default folder is `/etc/letsencrypt/live/%domain%`)

5. Check that certificates is valid using `sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/%domain%/fullchain.pem`
6. Copy new certificates to `./crt` directory

7. Replace `./ngx/https.conf` with the following:
```nginx
# ./ngx/https.conf
ssl_certificate /etc/letsencrypt/live/$NGX_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$NGX_DOMAIN/privkey.pem;
ssl_session_timeout 1h;
ssl_session_cache shared:MozSSL:10m;  # about 40000 sessions
ssl_session_tickets off;
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers off;

proxy_pass_header Server;
proxy_set_header  Host            $http_host;
proxy_set_header  X-Real-IP       $remote_addr;
proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;

# HSTS (ngx_http_headers_module is required) (63072000 seconds)
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Content-Type-Options    "nosniff";
add_header Referrer-Policy           "strict-origin-when-cross-origin";
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains;";
add_header Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()";
add_header X-Frame-Options           "SAMEORIGIN";
add_header X-XSS-Protection           1;
add_header X-Robots-Tag               none;
```

8. Replace `./ngx/cors.conf` with the following:
```nginx
# ./ngx/cors.conf
if ($request_method = 'OPTIONS') {
  # Custom headers and headers various browsers *should* be OK with but aren't
  # add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';

  add_header 'Access-Control-Allow-Origin'    '*';
  add_header 'Access-Control-Allow-Methods'   'GET, POST, DELETE, OPTIONS, PUT';
  add_header 'Access-Control-Allow-Headers'   '*';
  add_header 'Access-Control-Max-Age'         1728000; # 20 days
  add_header 'Content-Type'                   'text/plain; charset=utf-8';
  add_header 'Content-Length'                 0;

  return 204;
}

```
9. Replace `./ngx/default.conf` with the following:
```nginx
# ./ngx/default.conf
server {
    listen 80;
    server_name $NGX_DOMAIN www.$NGX_DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        allow all;
        default_type "text/plain";
        alias /var/www/html/acme-challenge/;
        break;
    }

    return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name $SYNAPSE_DOMAIN;

  include /etc/nginx/https.conf;

  location /_matrix {
    proxy_pass http://$SYNAPSE_DOMAIN:$SYNAPSE_PORT;
    include /etc/nginx/cors.conf;
  }

  # TODO [snow]: why? is it typo? Should it be here at all?
  location /.well-known {
    proxy_pass http://$SYNAPSE_DOMAIN:$SYNAPSE_PORT;
    include /etc/nginx/cors.conf;
  }

  location /_synapse/client {
    proxy_pass http://$SYNAPSE_DOMAIN:$SYNAPSE_PORT;
    include /etc/nginx/cors.conf;
  }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name $ELEMENTS_DOMAIN;

  include /etc/nginx/https.conf;

  location / {
    proxy_pass http://$ELEMENTS_DOMAIN:$ELEMENTS_PORT;
    include /etc/nginx/cors.conf;
  }
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name $NGX_DOMAIN www.$NGX_DOMAIN;

  include /etc/nginx/https.conf;

  location ^~ /.well-known/acme-challenge/ {
      allow all;
      default_type "text/plain";
      alias /var/www/html/acme-challenge/;
      break;
  }
}

```
9. Run `docker compose up`. Check out `https://$NGX_DOMAIN`, login with the created used.

### Caddy

Caddy will be used for the reverse proxy. This will handle incomming HTTPS connections and forward them to the correct docker containers. It a simple setup process and Caddy will automatically fetch and renew Let's Encrypt certificates for us!

1. Follow caddy setup guide

2. Head to your user directory: `cd`

3. Create Caddy file: `sudo nano Caddyfile`

   Recommended:
   - Limited Matrix paths (based on docs)
   - Security Headers
   - No search engine indexing

```
$SYNAPSE_DOMAIN {
  reverse_proxy /_matrix/* $SYNAPSE_DOMAIN:$SYNAPSE_PORT
  reverse_proxy /_synapse/client/* $SYNAPSE_DOMAIN:$SYNAPSE_PORT

  header {
    X-Content-Type-Options nosniff
    Referrer-Policy  strict-origin-when-cross-origin
    Strict-Transport-Security "max-age=63072000; includeSubDomains;"
    Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()"
    X-Frame-Options SAMEORIGIN
    X-XSS-Protection 1
    X-Robots-Tag none
    -server
  }
}

element.example.ru {
  encode zstd gzip
  reverse_proxy $ELEMENTS_DOMAIN:$ELEMENTS_PORT

  header {
    X-Content-Type-Options nosniff
    Referrer-Policy  strict-origin-when-cross-origin
    Strict-Transport-Security "max-age=63072000; includeSubDomains;"
    Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=(), interest-cohort=()"
    X-Frame-Options SAMEORIGIN
    X-XSS-Protection 1
    X-Robots-Tag none
    -server
  }
}
```

4. Enable the config: caddy reload

5. Run `docker compose up`. Check out `https://$NGX_DOMAIN`, login with the created used.

## Login

Check out `https://$NGX_DOMAIN`, login with the created in previous step user.

## Update

Don't forget to update every now and then

Pull the new docker images and then restart the containers:

`docker compose pull && docker compose up -d`

## See also

- [Database backups](DatabaseBackups.md)
- [Bridges](Bridges.md)
