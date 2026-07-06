#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export INSTALL_SOURCE_MODE=local
export SKIP_GIT_PULL=1
exec "$DIR/tools/install_ios_to_iphone.sh"
