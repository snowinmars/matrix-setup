# How to setup Matrix bridges

## Arch

### Definitions

The bridge is a flow between two servers. Messages passes from one server to another through the bridge. One of the servers should be a Matrix server ___aka synapse aka homeserver___. The other one could be any server.

Appservice is bridge engine; bot runs the bridge. it is not 'bot' itself - appservice use bots ___aka puppets___ to operate inside the servers.

A puppet is an account in some system. A puppet is used to CRUD messages in a server.

Do read [Types of bridging docs](https://matrix.org/docs/guides/types-of-bridging). Long story short:
- puppet is an account in external messenger (external from bridge point of view). Bridge use a puppet to operate under your name somewhere.
- if you use `native matrix account -> bridge -> external puppet account` schema, you use simple puppeted bridge
- if you use `matrix puppet account -> bridge -> external puppet account` schema, you use double-puppeted bridge
- if bridge does not use puppets, try to find out why. Using at least one puppet is a good idea

A manhole is a 'bridge debugger'.

### Integration server (Dimension)

See notes about integration server at the [README.md](README.md). TL;DR: do not use integration servers: a bot can communicate with synapse directly.

### Secrets

TODO [snow]: What parts of configurations should not be exposed (access keys etc) and what parts could be exposed to public?

### Data

Do use database per bot. You can use one docker container, but do use separated databases. It is important.

TODO [snow]: What data brigdes store? Is it anonymus etc, or it stores usernames, ips or whatever?

## Bridge: Matrix <-> Telegram

### What puppet to use

You can use any telegram account: you can use bot or you can use a real one. In this guide we will use bot, but real account works in the same way.

#### Bot

Procs:
- it's easy to (re)create or to delete
- it's free
- it do not deanonimyze you (almost)

Cons:
- a bot cannot start dialog with a user; a bot can continue dialog with a user
- a bot should be explicitly added into the chat

#### Real account

Procs:
- real account can start dialog with a user

Cons:
- hard to find, easy to lose and ~~im~~possible to forget
- requires phone number

### Step-by-step

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
  image: dock.mau.dev/mautrix/telegram:v0.13.0
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

3. `docker compose up` once to create `./mautrix-telegram/config.yaml`. The `mautrix-telegram` container will exit with code 0.

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
        proxy_pass http://$MAUTRIX_TELEGRAM_DOMAIN:29317;
    }
```

Add this route to all nginx servers.

10. Set bot permissions to something meaningfull:

```
# ...
bridge:
    # ...
    permissions:
        '*': relaybot
        '@$USERNAME:$SYNAPSE_DOMAIN': admin
```

10. Run `docker compose up` - no container should fail.

11. Create e2ee room, click 'Invite' (not 'Add widgets, bridges & bots'), print `@$BOT_USERNAME:$SYNAPSE_DOMAIN` and click 'Send'.

The bot should be added into the room without errors. There should be two users in the rooms now: you and the bot. If it's true, you should be able to chat with the bot without prefixes. If it's not true, you should prefix your command with `./mautrix-telegram/config.yaml -> bridge -> command_prefix` (`!tg` by default).

12. Print 'help' - bot should response. If none happens, check the bot permissions.

## Register telegram bot

1. Go to @BotFather at Telegram messenger

2. Create a bot - it will provide you a secret access key `$TELEGRAM_BOT_ACCESS_KEY` - like '1111:aaaa'

3. Ensure that your telegram bot have `Group settings -> Privacy mode -> disabled`. This property affects bot's message access.

4. Add the telegram bot to a telegram chat. Ensure that in the user list is have a 'can read message' status. If it has 'cannot read messages' status, the bot will not be able to transfer messages from telegram to matrix.

## Setting up the bridge

At this point you should have:
- a e2ee room with you and the mautrix bot, that responses with something on 'help' command
- a telegram chat with telegram bot, that can read chat messages

You will use at least N+1 channels at the matrix server: one for bot configuration and N for bridging. That's because some bot configurations are secret, and you should never expose it to strangers. Furthermore, some bot commands are disabled in chats.

Pick a channel that will be used for bot configuration. In this channel there should be just you and the bot.

The following commands are used to handle telegram puppet state:
- `login` - allow the bridge to operate under telegram puppet account
- `logout` - forbig the bridge to operate under telegram puppet account
- `ping` - get logged in or logged out state of your telegram puppet account
- `username`/`displayname` - set telegram puppet account username/displayname, if puppet is not bot. Bot cannot set it's name using this command

Mautrix telegram is double-puppeted bridge, it use default matrix puppet. You can use it as is or replace default matrix puppet with you custom matrix account using the following commands:
- `login-matrix` - allow the bridge to operate under matrix puppet account
- `logout-matrix` - forbig the bridge to operate under matrix puppet account
- `ping-matrix` - get logged in or logged out state of your matrix puppet account

1. Print 'login' and paste `$TELEGRAM_BOT_ACCESS_KEY` - it will grant matrix full access to your telegram bot. You can read about these properties above. If bot throw an error, read logs from `mautrix-telegram` container.

2. Now you have to setup a bridge - to link matrix room and telegram chat.

Go to https://api.telegram.org/bot$TELEGRAM_BOT_ACCESS_KEY/getUpdates and get a chat id, that you want to link. If you see no chat id, kick and add the telegram bot from telegram chat. That will refresh the data.

Create a new room and invite the bot. To allow the bot to handle edit/delete actions, make the bot moderator: 'Room settings -> People -> the bot -> Power level -> Moderator'

3. Print 'bridge -chatid'

4. Print 'continue'. At this point, you should be able to send a message from matrix to telegram.

## Bridge: Discord <-> Matrix



## Known memes

Q: I remove a message and bot ignore it. Why?
A: Idk, but try to wait for several minutes.

Q: Bot does not send a message. Why?
A: Check that both puppets can read and write messages in the chats. Check docker container logs.

## See also

[1] https://github.com/snowinmars/matrix-setup
[2] https://habr.com/ru/post/665766/
[3] https://docs.mau.fi/bridges/python/setup.html
[4] https://ssine.ink/en/posts/matrix-bot-and-bridges/
[5] https://docs.mau.fi/bridges/general/registering-appservices.html
