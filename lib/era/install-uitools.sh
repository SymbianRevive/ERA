#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo -e ' ==> Downloading uitools sources'
_clone_or_pull "${SYMBIAN_BUILD_REPO:-https://github.com/SymbianRevive/uitools.git}" uitools
>&2 echo -e ' ==> Installing uitools'
&>/dev/null pushd uitools/group/
  >&2 sbs -q --jobs "${MAKEJOBS}" -c tools2
&>/dev/null popd
