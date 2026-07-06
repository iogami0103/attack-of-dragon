#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export INSTALL_SOURCE_MODE=github_latest
exec "$DIR/tools/install_ios_to_iphone.sh"
