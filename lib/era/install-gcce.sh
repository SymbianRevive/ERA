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
    >&2 echo "   ==> Patching ${name}"
    for patch in "${_AUX_DIR}"/patch/"${dir}"/*.patch ; do
      >&2 echo "    ==> Applying ${patch}"
      >/dev/null POSIXLY_CORRECT=1 patch -p1 -Nr- <"${patch}" &>/dev/null ||:
    done
    shopt -u nullglob

    rm -rf _builddir/
    mkdir -p _builddir/
    &>/dev/null pushd _builddir/
      >&2 echo "   ==> Configuring ${name}"
      >&2 make distclean ||:
      shopt -s globstar nullglob
      >&2 rm -f ./**/config.cache ||:
      shopt -u globstar nullglob
      >&2 PATH="${_AUX_DIR}"/stubs:"${PATH}" ../configure \
        --prefix="$(realpath -- "${prefix}")" \
        "$@" \
        CFLAGS="-O2" \
        CXXFLAGS="-O2" \
        ASFLAGS="-O2" \
        LDFLAGS="-O2"
      >&2 make clean
      >&2 echo "   ==> Making ${name}"
      >&2 PATH="${_AUX_DIR}"/stubs:"${PATH}" make ${MAKEFLAGS}
      >&2 echo "   ==> Installing ${name}"
      >&2 PATH="${_AUX_DIR}"/stubs:"${PATH}" make install-strip
    &>/dev/null popd
  &>/dev/null popd
}

rm -rf "${GCCE463_PREFIX}"

>&2 echo ' ==> Downloading CodeSourcery GCCE'
&>/dev/null rm -rf gcce/
&>/dev/null mkdir -p gcce/
&>/dev/null pushd gcce/
[[ ! -f "../gcce.tbz2" ]] \
  && wget -O ../gcce.tbz2 "${GCCE_URL:-https://sourcery.sw.siemens.com/public/gnu_toolchain/arm-none-symbianelf/arm-2012.03-42-arm-none-symbianelf.src.tar.bz2}"
tar -xjf ../gcce.tbz2 --strip-components=1
shopt -s nullglob
readonly GCCE_COMPONENT_ARCHIVES=(./*.tar.bz2)
shopt -u nullglob
_multi_extract _just_extract "${GCCE_COMPONENT_ARCHIVES[@]}" >/dev/null
&>/dev/null popd

>&2 echo ' ==> Building CodeSourcery GCCE'
&>/dev/null pushd gcce/
  _GCCE_BUILD_ROOT="$(pwd)"

  _gcce_build_target binutils '' '' \
    --target=arm-none-symbianelf

  rm -rf gmp.install
  _gcce_build_target gmp GMP "${_GCCE_BUILD_ROOT}"/gmp.install \
    --disable-shared
  _gcce_build_target mpfr MPFR "${_GCCE_BUILD_ROOT}"/gmp.install \
    --with-gmp="${_GCCE_BUILD_ROOT}"/gmp.install \
    --disable-shared
  _gcce_build_target mpc MPC "${_GCCE_BUILD_ROOT}"/gmp.install \
    --with-gmp="${_GCCE_BUILD_ROOT}"/gmp.install \
    --disable-shared

  _gcce_build_target gcc GCC '' \
    --target=arm-none-symbianelf \
    --enable-languages=c,c++,lto \
    --disable-libstdcxx-pch
    --with-gmp="${_GCCE_BUILD_ROOT}"/gmp.install \
    --disable-libmudflap \
    --disable-libssp \
&>/dev/null popd

"${GCCE463_PREFIX}/bin/arm-none-symbianelf-g++" -x "c++" -o /dev/null - <<<"int main(){}"
