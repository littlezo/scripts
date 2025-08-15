#!/bin/bash

echo '* soft nofile 524288
* hard nofile 524288
* soft nproc 524288
* hard nproc 524288
root soft nofile 524288
root hard nofile 524288
* soft core unlimited
* hard core unlimited
root soft core unlimited
root hard core unlimited
' > /etc/security/limits.conf