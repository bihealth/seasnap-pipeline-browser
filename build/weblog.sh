#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs
cd logs
python3 -m http.server 8080 &
echo $! > webserver.pid
