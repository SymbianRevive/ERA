#!/usr/bin/env zsh
set -eu -o pipefail -o err_return

export EPOCROOT=${HOME}/epocroot

export PATH=${EPOCROOT}/unixsup/bin${PATH:+:${PATH}}

if ! &>/dev/null mountpoint "${EPOCROOT}"/epoc32 ; then
  _temp=$(mktemp -d)

  sudo mount --rbind "${EPOCROOT}"/epoc32 "${_temp}"
  sudo mount --make-rslave "${_temp}"

  casefusefold "${EPOCROOT}"/epoc32{.real,}

  </proc/mounts awk -v "PFX=${_temp}" '(index($2,PFX)==1&&length($2)>length(PFX)){print$2}' |while read -r mnt ; do
    sudo mount --bind "${mnt}" "${EPOCROOT}/epoc32${mnt#${_temp}}"
  done
fi

export PATH=${PATH}:${EPOCROOT}/epoc32/tools/sbs/bin:${EPOCROOT}/epoc32/tools

export SBS_GCCE1210BIN=${EPOCROOT}/epoc32/tools/gcce-12.1.0/bin
export SBS_GCCE463BIN=${EPOCROOT}/epoc32/tools/gcce-4.6.3/bin

export SBS_GCCX86BIN=/usr/bin
export SBS_GCCX86LIB=/usr/lib
export SBS_GCCX86INC=/usr/include

export SBS_SHELL=/usr/bin/bash
export SBS_HOME=${EPOCROOT}/epoc32/tools/sbs

exec "$@"
