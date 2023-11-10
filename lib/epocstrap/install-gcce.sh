#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

>&2 echo ' ==> Downloading CodeSourcery GCCE'
if [[ ! -d gcce/ ]] ; then
  &>/dev/null rm -rf gcce-unpack/
  &>/dev/null mkdir -p gcce-unpack/
  &>/dev/null pushd gcce-unpack/
    wget -O- ${GCCE_URL:-https://sourcery.sw.siemens.com/public/gnu_toolchain/arm-none-symbianelf/arm-2012.03-42-arm-none-symbianelf.src.tar.bz2} | >&2 tar -xjf- --strip-components=1
    shopt -s nullglob
    readonly GCCE_COMPONENT_ARCHIVES=(./*.tar.bz2)
    shopt -u nullglob
    _multi_extract _just_extract "${GCCE_COMPONENT_ARCHIVES[@]}" >/dev/null
  &>/dev/null popd
  &>/dev/null mv gcce-unpack gcce ||rm -rf gcce
fi
>&2 echo ' ==> Building CodeSourcery GCCE'
&>/dev/null pushd gcce/
  >&2 echo '  ==> Building binutils'
  &>/dev/null pushd binutils/
    >&2 make distclean ||:
    shopt -s globstar
    >&2 rm -f ./**/config.cache ||:
    shopt -u globstar
    &>/dev/null ./configure \
      --target=arm-none-symbianelf \
      --prefix="${GCCE463_PREFIX}" \
      CXXFLAGS="-fpermissive -w -O2" \
      CFLAGS="-fpermissive -w -O2"
    >&2 make clean ||:
    >&2 make -k ${MAKEFLAGS} ||:
    >&2 make -k install ||:
  &>/dev/null popd
  >&2 echo '  ==> Building GCC'
  &>/dev/null pushd gcc/
    >&2 make distclean ||:
    shopt -s globstar
    >&2 rm -f ./**/config.cache ||:
    shopt -u globstar
    &>/dev/null ./configure \
      --target=arm-none-symbianelf \
      --prefix="${GCCE463_PREFIX}" \
      --enable-languages=c,c++,lto,fortran \
      CXXFLAGS="-fpermissive -w -O2" \
      CFLAGS="-fpermissive -w -O2"
    >&2 make clean ||:
    >&2 make -k ${MAKEFLAGS} ||:
    >&2 make -k install ||:
  &>/dev/null popd
&>/dev/null popd
