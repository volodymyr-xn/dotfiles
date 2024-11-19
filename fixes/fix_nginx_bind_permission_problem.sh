#!/usr/bin/env bash

sudo setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx
