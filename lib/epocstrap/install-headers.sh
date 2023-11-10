#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo -e ' ==> Downloading headers'
_clone_or_pull "${SYMBIAN_HEADERS_REPO:-https://github.com/SymbianRevive/symbian-headers.git}" symbian-headers
&>/dev/null pushd symbian-headers/
  >&2 echo -e ' ==> Installing headers'
  shopt -s nullglob
  cp -a ./* "${REAL_EPOCROOT}"/epoc32/include/
  shopt -u nullglob
&>/dev/null popd
