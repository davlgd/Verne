#!/bin/bash
set -euo pipefail

OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
FILE_NAME="verne-${OS_NAME}-${ARCH}"
BIN_FOLDER="bin"

echo "Building verne for ${OS_NAME}/${ARCH} as ${FILE_NAME}..."
mkdir -p "${BIN_FOLDER}"
v -prod -o "${BIN_FOLDER}/${FILE_NAME}" src/

(shasum -a 512 "${BIN_FOLDER}/${FILE_NAME}" 2>/dev/null || sha512sum "${BIN_FOLDER}/${FILE_NAME}") > "${BIN_FOLDER}/${FILE_NAME}.sha512"
(shasum -a 256 "${BIN_FOLDER}/${FILE_NAME}" 2>/dev/null || sha256sum "${BIN_FOLDER}/${FILE_NAME}") > "${BIN_FOLDER}/${FILE_NAME}.sha256"
