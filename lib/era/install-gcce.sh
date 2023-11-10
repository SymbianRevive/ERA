#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

_gcce_build_target () {
  local dir name prefix
  dir=${1:?missing dir}
  name=${2:-$dir}
  prefix=${3:-$GCCE463_PREFIX}
  shift 3

  >&2 echo "  ==> Building ${name}"
  &>/dev/null pushd "${dir}"/
    shopt -s nullglob
    for patch in "${_AUX_DIR}"/lib/epocstrap/patch/gcc/*.patch ; do
      &>/dev/null POSIXLY_CORRECT=1 patch -p1 -Nr- <"${patch}" &>/dev/null
    done
    shopt -u nullglob

    >&2 make distclean ||:
    shopt -s globstar
    >&2 rm -f ./**/config.cache ||:
    shopt -u globstar
    &>/dev/null ./configure \
      --target=arm-none-symbianelf \
      --prefix="$(realpath -- "${prefix}")" \
      "$@" \
      CXXFLAGS="-fpermissive -w -O2 -m32" \
      CFLAGS="-fpermissive -w -O2 -m32" \
      ASFLAGS="-m32 -O2" \
      LDFLAGS="-m32 -O2"
    >&2 make clean ||:
    >&2 make -k ${MAKEFLAGS} ||:
    >&2 make -k install install-strip ||:
  &>/dev/null popd
}

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
  _gcce_build_target binutils

  rm -rf gmp.install
  _gcce_build_target gmp GMP gmp.install --disable-shared
  _gcce_build_target mpfr MPFR gmp.install --with-gmp="$(pwd)"/gmp.install --disable-shared
  _gcce_build_target mpc MPC gmp.install --with-gmp="$(pwd)"/gmp.install --disable-shared

  _gcce_build_target mpc MPC gmp.install --with-gmp="$(pwd)"/gmp.install --disable-shared

  _gcce_build_target gcc GCC '' \
    --enable-languages=c,c++,lto \
    --with-gmp="$(pwd)"/gmp.install \
    --disable-libmudflap \
    --disable-libssp \
    --disable-libstdcxx-pch
&>/dev/null popd
