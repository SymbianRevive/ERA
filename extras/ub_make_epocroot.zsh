#!/usr/bin/env zsh
set -xeu -o pipefail -o err_return

. "${0:a:h}/common.zsh"

[[ "$(ps -o comm= -p "$$")" = 'zsh'* ]] || die 'this script must be run in zsh'

[[ "${EUID}" -eq 0 ]] || die 'this script must only be run as root'

TARGET=${TARGET:?need TARGET}

[[ -e "${TARGET}" ]] && die 'TARGET must not exist'

STAGE=$(mktemp -d)
mount -t tmpfs -o size=24G none "${STAGE}"

FIFOBRIDGE=$(mktemp -u)
mkfifo -m0600 "${FIFOBRIDGE}"

trap ' \
	set +eu +o err_return ; \
	while >/dev/null kill %% ; do : ; done ; \
	{ umount -R "${STAGE}" || \
		umount -lR "${STAGE}" \
	} ; \
	rmdir "${STAGE}" ; \
	rm -f "${FIFOBRIDGE}" ; \
	exit' EXIT INT

# lol this is such a backdoor :sob:
( tail -f "${FIFOBRIDGE}" |while read -r CMD ; do eval "${CMD}" ; done ) &

SUITE=${SUITE:-noble}
COMPONENTS=${COMPONENTS:-main,restricted,universe,multiverse}

_extras=(
	ubuntu-minimal
	linux-image-generic
	linux-firmware
	initramfs-tools
	systemd-sysv
	systemd-boot
	systemd-boot-efi
	efibootmgr
	passwd
	python3
	python-is-python3
	perl
	ca-certificates
	moreutils
	parallel
	e2fsprogs
	fuse2fs
	mount
	gawk
	lz4
	aria2
	wget
	curl
	sudo
	build-essential
	autoconf
	automake
	libarchive-tools
	patchelf
	libgmp-dev
	libmpfr-dev
	libmpc-dev
	gcc
	gcc-multilib
	'g++'
	'g++-multilib'
	git
)

USE_TARBALL=${USE_TARBALL:-}

_exargs=()

if [[ -f "${USE_TARBALL}" ]] ; then
	_exargs+=( --unpack-tarball="${USE_TARBALL}" )
elif [[ -n "${USE_TARBALL}" ]] ; then
	_exargs+=( --make-tarball="${USE_TARBALL}" )
fi

_arch=$(uname -m)
[[ "${_arch}" = x86_64 ]] && _arch=amd64
MIRROR=${MIRROR:-http://archive.ubuntu.com/ubuntu}
debootstrap "${_exargs[@]}" \
	--exclude='nano' \
	--include="$(ajoin , "${_extras[@]}")" \
	--components="${COMPONENTS}" \
	--arch="${_arch}" \
	"${SUITE}" "${STAGE}" \
	"${MIRROR}"

_components=()
asplit _components , "${COMPONENTS}"

cat >"${STAGE}/etc/apt/sources.list" <<.
deb ${MIRROR} ${SUITE} ${_components[*]}
.

echo -n 'builder' >"${STAGE}/etc/hostname"

cp -fv '/etc/resolv.conf' "${STAGE}/etc/resolv.conf"

chr () { chroot "${STAGE}" "$@" || return $? }

chr bash -c ' \
	export DEBIAN_FRONTEND=noninteractive && \
	dpkg --add-architecture i386 && \
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y zlib1g-dev:i386'

chr bash -c ' \
	export PATH=${PATH:+${PATH}:}/usr/sbin && \
	groupadd -g 1001 ubuntu && \
	useradd -s /usr/bin/bash -m -G sudo -u 1001 -g 1001 ubuntu && \
	<<<"ubuntu:ubuntu" chpasswd'

for m in /proc /sys /dev /run ; do
	mount --rbind "$m" "${STAGE}$m"
	mount --make-rslave "${STAGE}$m"
done

_njob=$(( max(4, $(nproc) - 1) ))

rsync -r "${0:a:h:h}/" "${STAGE}/home/ubuntu/epocstrap/"

chr chown -R ubuntu: '/home/ubuntu/epocstrap'

ERA_CACHE=${ERA_CACHE:-/tmp/era_cache}
if [[ -n "${ERA_CACHE}" ]] ; then
	mkdir -p "${ERA_CACHE}" "${STAGE}/home/ubuntu/.cache"
	mount --bind "${ERA_CACHE}" "${STAGE}/home/ubuntu/.cache"
	chr chown -R ubuntu: '/home/ubuntu/.cache'
fi

touch "${STAGE}${FIFOBRIDGE}"
mount --bind "${FIFOBRIDGE}" "${STAGE}${FIFOBRIDGE}"

cat >"${STAGE}/usr/local/bin/umount" <<.
#!/usr/bin/env bash
set -euo pipefail

_args=()

while getopts ':lR' o ; do
	case "\$o" in
		l)
			_args+=(-l)
			;;
		R)
			_args+=(-R)
			;;
		*)
			exit 1
			;;
	esac
done

shift \$((OPTIND-1))

for p in "\$@" ; do
	_args+=("${STAGE}\$p")
done

echo "umount \${_args[*]}" >>"${FIFOBRIDGE}"
sleep 2
.
cat >"${STAGE}/usr/local/bin/mount" <<.
#!/usr/bin/env bash
set -euo pipefail

_args=()

while getopts ':t:o:' o ; do
	case "\$o" in
		t)
			_args+=(-t "\${OPTARG}")
			;;
		o)
			_args+=(-o "\${OPTARG}")
			;;
		*)
			exit 1
			;;
	esac
done

shift \$((OPTIND-1))

for p in "\$@" ; do
	_args+=("${STAGE}\$p")
done

echo "mount \${_args[*]}" >>"${FIFOBRIDGE}"
sleep 2
.
cat >"${STAGE}/usr/local/bin/chattr" <<.
#!/usr/bin/env bash
set -euo pipefail

_args=()

for a in "\$@" ; do
	case "\$a" in
		-*|+*)
			_args+=("\$a")
			;;
		*)
			_args+=("${STAGE}\$a")
			;;
	esac
done

echo "chattr \${_args[*]}" |sudo >/dev/null tee -a "${FIFOBRIDGE}"
sleep 2
.

chmod 0755 "${STAGE}/usr/local/bin"/{umount,mount,chattr}

chr sudo -u ubuntu bash -c ' \
	set -o pipefail
	export PATH=/usr/local/bin${PATH:+:${PATH}}:/usr/sbin && \
	cd ~/epocstrap && \
	bin/epocstrap \
		-j'"${_njob}"' \
		-r "${HOME}/epocroot.ext4" \
		-f -d modern-gcc 2>&1 \
		|tee "${HOME}/epocstrap.log"'

tar --numeric-owner -cf "${TARGET}" "${STAGE}"/home/ubuntu/{epocroot.ext4,epocstrap.log}
