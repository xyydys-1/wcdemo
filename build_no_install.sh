#!/bin/bash
set -euo pipefail
: "${THEOS:?Set THEOS to your Theos directory first}"
make clean
make -j1
