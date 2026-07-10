#!/usr/bin/env bash

# Locally trusted development certificates (HTTPS for *.localhost domains).
# libnss3-tools provides certutil, which mkcert needs to add its CA to the
# Firefox/Chrome trust stores.

sudo apt install mkcert libnss3-tools

# Add the local CA to the system and browser trust stores (once per machine)
mkcert -install
