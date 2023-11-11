#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo -e ' ==> Bootstrapping import libraries'
wget -O- "${SYMBIAN_IMPLIBS_URL:-https://github.com/SymbianRevive/symbian-implibs/releases/${SYMBIAN_IMPLIBS_TAG:-latest}/download/release_armv5.tar.lz4}" \
  | >&2 tar -I lz4 -C "${EPOCROOT}" -xf-
