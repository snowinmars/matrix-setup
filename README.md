# What is this guide about

In this guide I'll describe how to create fully self hosted decentralized e2ee communication system.

I'll use matrix and xmpp as an examples, but it's ok to use anything, that you can wrap into docker container.

This guide is about step-by-step improvements. Feel free to skip or ignore something that you don't need right now.

# What do I need to know to start

Be not afraid.

Linux - a bit. Docker - a bit. All the other stuff you'll learn in the way.

# How to read this guide

1. [INIT.md](1.INIT.md) - initial setup. The only really required step
1. [MATRIX.md](2.MATRIX.md) - create element+synapse servers
  1. [BRIDGES.md](2.1.BRIDGES.md) - create matrix bridges
1. [XMPP.md](3.XMPP.md) - create xmpp server
1. [PARTITIONS.md](4.PARTITIONS.md) - move servers into encrypted partition
1. [NETWORK.md](5.NETWORK.md) - move servers into private network

# Next

Feel free to share on modify this guide under GNU/GPL.

## See also

1. https://habr.com/ru/post/665766/
1. https://docs.mau.fi/bridges/python/setup.html
1. https://ssine.ink/en/posts/matrix-bot-and-bridges/
1. https://docs.mau.fi/bridges/general/registering-appservices.html
