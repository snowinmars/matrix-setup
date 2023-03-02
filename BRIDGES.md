# How to setup Matrix bridges

See notes about integration server at the [README.md](README.md).

    Before we start: use database per bot. You can use one docker container, but do use separated databases.

## Telegram

You can use any telegram account: you can use bot or you can use a real one.

1. Create empty `./mautrix-telegram` directory:
```
.
├── crt/
├── element/
├── ngx/
├── postgres/
├── synapse/
├── mautrix-telegram/
└── docker-compose.yaml
```

2. Add mautrix/telegram to `./docker-compose.yaml`:
```yaml
# ./docker-compose.yaml
mautrix-telegram:
  image: dock.mau.dev/mautrix/telegram
  container_name: mautrix-telegram
  build:
    context: ./mautrix-telegram
  depends_on:
    - matrix-element
  # restart: unless-stopped
  volumes:
    - ./mautrix-telegram:/data:z
  networks:
    default:
      ipv4_address: $MAUTRIX_TELEGRAM_DOMAIN
```

3. `docker compose up` once to create `./mautrix-telegram/config.yaml`

4. Go to https://my.telegram.org/apps and register a telegram app. You will need `api_id` and `api_hash` values from ['App configuration'](https://my.telegram.org/apps) page.

`api_id` and `api_hash` values are NOT values from BotFather api key.

5. This `./mautrix-telegram/config.yaml` config is really big, so we'll start with much simpler configuration. Replace all the `./mautrix-telegram/config.yaml` content with the following:

```yaml
# ./mautrix-telegram/config.yaml
homeserver:
    address: http://$SYNAPSE_DOMAIN:8008 # beware of port!
    domain:  $SYNAPSE_DOMAIN
appservice:
    address:  http://$MAUTRIX_TELEGRAM_DOMAIN:29317
    database: sqlite:////data/mautrix-telegram.db
    bot_username: $BOT_USERNAME
    public:
        enabled:  true
        prefix:   /telegram-bridge
        external: http(s)://$NGX_DOMAIN/telegram-bridge
telegram:
    api_id: $TELEGRAM_API_ID
    api_hash: $TELEGRAM_API_HASH
bridge:
    max_initial_member_sync: 20  # 每个群初始化时同步多少用户，太大可能导致服务器僵尸用户爆炸多
    sync_channel_members:    false
    encryption:
        allow: true
        default: true
    permissions:
        '*': relaybot
        '@$USERNAME:$SYNAPSE_DOMAIN': admin
        domain: user
logging:
    version: 1
    formatters:
        colored:
            (): mautrix_telegram.util.ColorFormatter
            format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
        normal:
            format: "[%(asctime)s] [%(levelname)s@%(name)s] %(message)s"
    handlers:
        console:
            class: logging.StreamHandler
            formatter: colored
    loggers:
        mau:
            level: DEBUG
        telethon:
            level: INFO
        aiohttp:
            level: INFO
    root:
        level: DEBUG
        handlers: [console]
```

6. Run `docker compose up` - the `mautrix-telegram` docker container should exit with code 0 and a message 'didn't find a registration file'.

But it will:
- - extend your `./mautrix-telegram/config.yaml`. Read it again and check out that everything matches expected values
- - generate `./mautrix-telegram/registration.yaml`. This files generates by a bot, but consumes with synapse service

Changes to `./mautrix-telegram/config.yaml` will be reflected into `mautrix-telegram/registration.yaml`, so:
- mount it from `./mautrix-telegram` directory into `matrix-synapse` container
- rebuild the registration file each time you change the config file

7. Add to `./docker-compose.yaml` the following:

```yaml
# ./docker-compose.yaml
matrix-synapse:
  # ...
  volumes:
      # ...
      - ./mautrix-telegram/registration.yaml:/data/brigres/telegram/registration.yaml
```

8. Edit `./synapse/homeserver.yaml`, add to the root level:

```yaml
# ./synapse/homeserver.yaml
app_service_config_files:
  - /data/brigres/telegram/registration.yaml
```

9. Extend `./ngx/default.conf` with mautrix-telegram routes.

```nginx
# ./ngx/default.conf
    location /telegram-bridge {
        proxy_pass http://10.10.10.10:29317;
    }
```

Add this route to all nginx servers.

10. Run `docker compose up` - no container should fail, telegram container should write something like 'will run forever'

11. Create e2ee room, click 'Invite' (not 'Add widgets, bridges & bots' one), print `@$BOT_USERNAME:$SYNAPSE_DOMAIN` and click 'Send'

The bot should be added into the room without errors. There should be two users in the rooms now: you and the bot. If it's true, you should be able to chat with the bot without prefixes. If it's not true, you should prefix your command with `./mautrix-telegram/config.yaml -> bridge -> command_prefix` (`!tg` by default).

12. Print 'help' - bot should response. If none happens, check the bot permissions.

## Setting up the bridge

At this point you should have a e2ee room with you and the bot, that responses with something on 'help' command.

Do read [Types of bridging docs](https://matrix.org/docs/guides/types-of-bridging). Long story short:
- puppet is an account in external messenger (external from bridge point of view). Bridge use a puppet to operate under your name somewhere.
- if you use `native matrix account -> bridge -> external puppet account` schema, you use simple puppeted bridge
- if you use `matrix puppet account -> bridge -> external puppet account` schema, you use double-puppeted bridge
- if bridge does not use puppets, try to find out why is it. Using at least one puppet is a good idea

### Commands

You should have a channel just with bot. This channel will be used for bot configuration. Bot will create another channels - for chats, private messages, etc.

The following commands are used to handle external puppet state:
- `login` - allow the bridge to operate under external puppet account
- `logout` - forbig the bridge to operate under external puppet account
- `ping` - get logged in or logged out state of your external puppet account
- `username`/`displayname` - set external puppet account username/displayname, if puppet is not bot. Bot cannot set it's name using this command

Mautrix telegram is double-puppeted bridge, it use default matrix puppet. You can use it as is or replace default matrix puppet with you custom matrix account using the following commands:
- `login-matrix` - allow the bridge to operate under matrix puppet account
- `logout-matrix` - forbig the bridge to operate under matrix puppet account
- `ping-matrix` - get logged in or logged out state of your matrix puppet account

12. Print 'login' and paste `$TELEGRAM_API_ID:$TELEGRAM_API_HASH` - it will grant matrix full access to your telegram bot. You can read about these properties above. If bot throw an error, read logs from `mautrix-telegram` container.

13. Now you have to link matrix room to telegram chat. Go to https://api.telegram.org/bot$TELEGRAM_API_ID:$TELEGRAM_API_HASH/getUpdates and get a chat id, that you want to link.

If you see no chat id, kick and add the telegram bot from telegram chat. That will refresh the data.

13. Print 'bridge -chatid'

13. Print 'continue' - you will be invited at least at one room - accept all invites and ensure that you can send messages from/to telegram.

