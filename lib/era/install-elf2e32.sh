#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo -e ' ==> Downloading elf2e32 sources'
_clone_or_pull "${SYMBIAN_BUILD_REPO:-https://github.com/SymbianRevive/elf2e32.git}" elf2e32
>&2 echo -e ' ==> Installing elf2e32'
&>/dev/null pushd elf2e32/group/
  >&2 sbs -k -q --jobs "${MAKEJOBS}" -c tools2
&>/dev/null popd
