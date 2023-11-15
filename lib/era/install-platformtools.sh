#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo -e ' ==> Downloading platformtools sources'
_clone_or_pull "${SYMBIAN_BUILD_REPO:-https://github.com/SymbianRevive/platformtools.git}" platformtools
>&2 echo -e ' ==> Installing platformtools'
&>/dev/null pushd platformtools/group/
  >&2 sbs -q --jobs "${MAKEJOBS}" -c tools2
&>/dev/null popd
