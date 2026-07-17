#!/usr/bin/env bash
set -e

gren make Server && mv app server
node server &
SERVER_PID=$!
trap "kill $SERVER_PID 2>/dev/null" EXIT
npx -y wait-on tcp:3456 -t 5s
gren run Tests
