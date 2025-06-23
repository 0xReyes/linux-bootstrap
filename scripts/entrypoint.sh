#!/bin/bash
set -euo pipefail

service ssh start
bash /tmp/server-config/scripts/bastion-setup.sh /tmp/server-config
tail -f /dev/null