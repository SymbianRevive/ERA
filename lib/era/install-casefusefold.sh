#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

LNXSUP_DIR=${EPOCROOT}/unixsup

>&2 echo -e ' ==> Downloading casefusefold'

_clone_or_pull "https://github.com/SymbianRevive/casefusefold.git" casefusefold

>&2 echo -e ' ==> Installing casefusefold'

make ${MAKEFLAGS} -C casefusefold clean
make ${MAKEFLAGS} -C casefusefold 'CC=clang' 'CXX=clang++' 'CCLD=clang++'
install -Dpsm0755 casefusefold/casefusefold -t "${LNXSUP_DIR}/bin/"

>&2 echo -e ' ==> Starting up casefusefold'

export PATH=${LNXSUP_DIR}/bin:${PATH}
mkdir -p "${EPOCROOT}"/epoc32{.real,}

casefusefold "${EPOCROOT}"/epoc32{.real,}
sleep 1
