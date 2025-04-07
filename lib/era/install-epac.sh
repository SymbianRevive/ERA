#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo -e ' ==> Bootstrapping EPAC'
wget -O- https://raw.githubusercontent.com/SymbianRevive/epac/refs/heads/main/bin/epac \
  | bash -s -- -c tools2_rel -S epac || :
