#!/usr/bin/env bash
set -euo pipefail

mkdir -p logs
cd logs
/usr/local/bin/Rscript ../weblog.R &
echo $! > webserver.pid
