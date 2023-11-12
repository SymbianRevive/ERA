#!/usr/bin/env bash
set -Eeuo pipefail

(( _IN_EPOCSTRAP ))

cat <<EOF >"${EPOCROOT}/epoc32/sbs_config/gcc.xml"
<?xml version="1.0" encoding="ISO-8859-1"?>
<build xmlns="http://symbian.com/xml/build" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://symbian.com/xml/build ../../schema/build/2_0.xsd">
    <var name="root.changes">
        <set name='VARIANT_HRH' value='\$(EPOCINCLUDE)/feature_settings.hrh'/>
    </var>
</build>
EOF

cat <<EOF >"${EPOCROOT}/epoc32/sbs_config/gcce.xml"
<?xml version="1.0" encoding="ISO-8859-1"?>
<build xmlns="http://symbian.com/xml/build" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://symbian.com/xml/build ../../schema/build/2_0.xsd">
    <var name="root.changes">
        <set name='VARIANT_HRH' value='\$(EPOCINCLUDE)/variant/symbian_os.hrh'/>
    </var>
</build>
EOF

>&2 echo -e ' ==> Downloading build tool sources'
_clone_or_pull "${SYMBIAN_BUILD_REPO:-https://github.com/SymbianRevive/symbian-build.git}" symbian-build
&>/dev/null pushd symbian-build/
  >&2 echo -e ' ==> Bootstrapping SBSv2 "raptor"'
  >&2 echo -e '  ==> Installing SBSv2'
  rm -rf "${SBS_HOME}"
  cp -a sbsv2/raptor "${SBS_HOME}"

  >&2 echo -e '  ==> Building auxilary tools for SBSv2'
  &>/dev/null pushd cross-plat-dev-utils/
    >&2 make ${MAKEFLAGS} -C "${SBS_HOME}"/util clean
    >&2 make ${MAKEFLAGS} -C "${SBS_HOME}"/util
  &>/dev/null popd

  >&2 echo -e ' ==> Installing common build utils'
  &>/dev/null cp -a --no-clobber sbsv1/abld/e32util/*.{pl,pm} "${EPOCROOT}"/epoc32/tools/ ||:

  >&2 echo -e ' ==> Bootstrapping tools2-x86'
  >&2 echo -e '  ==> Building libcrypto'
  >&2 ./build-openssl.sh
  >&2 echo -e '  ==> Building tools'
  shopt -s nullglob globstar
  SYMBIAN_BUILD_TOOLS2_BUILDS=(*tools/**/bld.inf sbsv1/**/group/bld.inf)
  shopt -u nullglob globstar
  SYMBIAN_BUILD_TOOLS2_BUILDS=("${SYMBIAN_BUILD_TOOLS2_BUILDS[@]/#/-b}")
  >&2 sbs -k -q --jobs "${MAKEJOBS}" -c tools2 "${SYMBIAN_BUILD_TOOLS2_BUILDS[@]}" ||:
  >&2 sbs -k -q --jobs "${MAKEJOBS}" -c tools2 "${SYMBIAN_BUILD_TOOLS2_BUILDS[@]}" ||:
&>/dev/null popd
