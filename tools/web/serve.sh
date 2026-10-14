#!/bin/sh
# Serves the web build ($NBA_ROOT/web-site) at http://localhost:8088 with what the game needs:
# COOP/COEP headers (threads), HTTP Range (the disc on demand) and the Brotli copies.
# Other devices on your network: http://<this Mac's IP>:8088 needs HTTPS for threads, so use
# localhost here, or a real server with HTTPS (see Caddyfile.server).
set -e
ROOT="${NBA_ROOT:-$HOME/NBAStreetRecomp}"
command -v caddy > /dev/null || brew install caddy
SITE="$ROOT/web-site" exec caddy run --config "$(dirname "$0")/Caddyfile" --adapter caddyfile
