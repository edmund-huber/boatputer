#!/bin/bash
set -euo pipefail

docker build -t boatputer-builder .
docker run --rm --privileged \
    -v /dev:/dev \
    -v "$(pwd)":/build/output \
    boatputer-builder
