#!/bin/sh
set -e

# This script runs as root to fix permissions on the mounted volume,
# then steps down to the 'openclaw' user to run the main application.

echo "Entrypoint: Fixing permissions for /home/openclaw/.openclaw..."
chown -R openclaw:openclaw /home/openclaw/.openclaw

# Execute the command passed to this script (from the Dockerfile's CMD)
# as the 'openclaw' user.
exec sudo -E -u openclaw "$@"
