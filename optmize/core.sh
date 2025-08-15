#!/bin/bash

curl -fsSL https://raw.githubusercontent.com/littlezo/scripts/main/conf.d/sysctl.conf > /etc/sysctl.conf
sysctl --system
sysctl -p