# Network

At this point you should have some docker containers, that provides communication services to users. It's time to hide these net from public.

## Initial arch

1. You have a PC with linux
1. There are a docker compose file
1. The PC runs the docker images
1. There are a reverse proxy container that connect docker bridge network with public Internet
1. A user can access the apps from public Internet using reverse proxy

## Target arch

1. You have a PC with linux **in your flat**
1. You have **a separate volume**
1. The volume is **encrypted** and NOT automounted
1. There are a docker compose file **on the volume**
1. The PC runs docker images
1. There are a **dns server** inside the network that resolves domain, so you **don't need to buy a domain**
1. There are a reverse proxy that connect docker bridge network with **wireguard server**
1. There are **a i2p-over-vpn tunnel**
1. So a user can access the apps from public Internet using i2p vpn tunneling

## PC requirements

TODO [snow]: add CPU/RAM/SSD requirements

I'll use arch linux as an example. Feel fre to choose whatever you like.

## Create a separate volume

Try to avoid system and application mixing. Just buy and external drive.

1. Pick a device `/dev/sdX`
1. Create a new partition `/dev/sdXY` on the device. You can use the device `/dev/sdX` itself, it doesn't matter, until there's only one partition on the disk

### dm-crypt

Run dm-crypt on `/dev/sdXY`: see [textguide](https://wiki.archlinux.org/title/Dm-crypt) and [videoguide](https://youtu.be/Lc5BV3P5kjc)

    Do not use any automatization or kinda. Be sure that if you plug your PC out of electricity, it will NOT restore back without your will

Main steps from guides above:

1. `sudo cryptsetup --verbose --cipher aes-xts-plain64 --key-size 512 --iter-time=4000 --hash sha512 luksFormat /dev/sdX`
1. `lsblk`
1. `sudo cryptsetup open --type luks /dev/sdX NAME`
1. `lsblk` - the device changed
1. `sudo cryptsetup -v status NAME`
1. `sudo cryptsetup open --type plain -d /dev/urandom /dev/sdXY NAME`
1. `sudo cryptsetup close NAME`

### zfs

Run zfs on top of dm-crypt on `/dev/sdXY`: see [guide](https://github.com/danboid/creating-ZFS-disks-under-Linux) and [another guide](https://gist.github.com/kdwinter/2e779abab2e25f8a0bdea7928860fbb5).

    Do not use any automatization or kinda. Be sure that if you plug your PC out of electricity, it will NOT restore back without your will

Main steps from guides above:

1. `sudo zpool create -o ashift=12 -m none -R /mnt NAME /dev/mapper/NAME`
1. `sudo zfs set mountpoint=/path/to/dir NAME`
1. `sudo zpool export NAME` to unmount
1. `sudo zpool import NAME` to mount
1. `sudo chown -R $USER:users /home/homk/prg/snowinmars/NAME`

### dm-crypt + zfs

So, full device flow is:

1. `sudo zpool status` - check status of zfs
1. `sudo cryptsetup open /dev/sdX NAME` - open ("mount") dm-crypt device
1. `sudo zpool import NAME` - import ("mount") zfs
1. ...work...
1. `sudo zpool export NAME` - export ("umount") zfs
1. `sudo cryptsetup close NAME` - close ("umount") dm-crypt device

**Do test** what happens if you hot unplug the device. Learn how to restore. Usefull commands:

1. `ls /dev/mapper` - list all dm-crypt devices
1. `lsblk` - check status of mounted dm-crypt devices
1. `sudo cryptsetup -v status NAME` - check status of dm-crypt
1. `sudo dmsetup info NAME` - info about NAME
1. `sudo lsof | grep NAME` - who uses NAME
1. `sudo fuser /dev/mapper/NAME` - who uses NAME

## Restore the apps

1. Open encrypted folder `.`
1. Restore all the docker apps, that you had before on the encrypted disk. Make sure it work before processing further
1. Reboot the system and make sure that docker apps won't run by themselves

## Add wireguard container

1. Create stub tree:
  1. `mkdir ./wireguard`
  1. `touch ./wireguard/Dockerfile` 

2. Add to `./wireguard/Dockerfile`
```dockerfile
# ./wireguard/Dockerfile
FROM lscr.io/linuxserver/wireguard:1.0.20210914
```

3. Add to `./docker-compose.yaml`
```dockerfile
# ./docker-compose.yaml
...
  wireguard:
    container_name: wireguard
    image: snowinmars/wireguard:1.0.0
    hostname: wireguard
    build:
      context: ./wireguard
      dockerfile: ./Dockerfile
    #depends_on:
    #  TODO[snow]: decide later:
    #    condition: service_healthy
    # restart: unless-stopped
    ports:
      - 51820:51820/udp
    volumes:
      - ./wireguard:/config
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - SERVERURL=localhost
      - SERVERPORT=51820
      - PEERS=1 # set to how many clients you will have on the vpn server
      - PEERDNS=auto
      - INTERNAL_SUBNET=10.13.13.0 #optional
      - ALLOWEDIPS=0.0.0.0/0 #optional
      - PERSISTENTKEEPALIVE_PEERS=all #optional
      - LOG_CONFS=false
    # healthcheck:
      # test: ["CMD-SHELL", "wget -O /dev/null http://localhost || exit 1"]
      interval: 60s
      timeout: 10s
      retries: 2
      start_period: 10s
      start_interval: 5s
```

4. Change ngx host name to something that you like. You can choose almost any host name - you are the god)

```
# ./docker-compose.yaml
...
  matrix-ngx:
    ...
    hostname: any.host.ru
```

5. Regenerate letsencrypt certs using new hostname

6. Ensure you have wireguard port (51820) open:
  1. Stop docker containers
  1. `sudo iptables -A INPUT  -p tcp --dport 51820 -j ACCEPT`
  1. `sudo iptables -A OUTPUT -p tcp --dport 51820 -j ACCEPT`
  1. `sudo iptables -A INPUT  -p udp --dport 51820 -j ACCEPT`
  1. `sudo iptables -A OUTPUT -p udp --dport 51820 -j ACCEPT`
  1. `nc -lp 51820`
  1. `sudo netstat -tulpn | grep 51820` - list open ports (should be in state LISTEN)
  1. Setup port forwarding in your router
  1. Check that port 51820 is opened using inline port checker
    1. Get local ip: `ifconfig INTERFACE`

7. Vpn up: `sudo wg-quick up ./wireguard/peer1/peer1.conf`

## Panic

`cryptsetup erase`

1. Think about panic signal. The `/dev/sdXY` partiotion now has the header and the encrypted data. The header contains encryption key, this key and the passphrase you have is required for any operation. You can't be sure that the passphrase won't leak, so there should be a way to destroy the header and to rewrite this sectors several times. It will make all the data unavaiable, and you will be no longer forced to protect the passphrase. See [#Panic] section, but you can skip it for now.
