#!/bin/bash
set -euo pipefail

# Start SSH service
service ssh start

# Execute the bastion setup script
sudo -u testuser bash /tmp/server-config/scripts/bastion-setup.sh /tmp/server-config

# Keep container running for inspection
tail -f /dev/null