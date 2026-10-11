#!/usr/bin/env zsh
set -xeu -o pipefail -o err_return

. "${0:a:h}/common.zsh"

[[ "$(ps -o comm= -p "$$")" = 'zsh'* ]] || die 'this script must be run in zsh'

[[ "${EUID}" -eq 0 ]] || die 'this script must only be run as root'

TARGET=${TARGET:?need TARGET}

[[ -e "${TARGET}" ]] && die 'TARGET must not exist'

STAGE=$(mktemp -d)

trap ' \
	set +eu +o err_return ; \
	{ umount -R "${STAGE}" || \
		umount -lR "${STAGE}" \
	} ; \
	rmdir "${STAGE}" ; \
	losetup -d "${LOOP}" ; \
	exit' EXIT INT

SUITE=${SUITE:-noble}
COMPONENTS=${COMPONENTS:-main,restricted,universe,multiverse}

qemu-img create "${TARGET}" 20G

parted -s "${TARGET}" -- \
	mklabel gpt \
	mkpart 'EFI' fat32 0GB 500MB \
	mkpart 'Linux' ext4 500MB -0GB \
	set 1 esp on

LOOP=$(sudo losetup --show -P -f "${TARGET}")

_parts=()
lsblk -nlpo NAME,TYPE "${LOOP}" \
	|grep 'part$' \
	|cut -f1 -d' ' \
	|LC_COLLATE=C sort -n \
	|while read -r p ; do _parts+=( "$p" ) ; done

mkfs.vfat -n 'EFI' -F32 "${_parts[1]}"
mkfs.ext4 -L 'Linux' "${_parts[2]}"

umask 0022

mount -t ext4 -o rw,noatime "${_parts[2]}" "${STAGE}"
mkdir -p "${STAGE}/boot/efi"
mount -t vfat -o rw,noatime,dmask=0022,fmask=0022 "${_parts[1]}" "${STAGE}/boot/efi"

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
	wget
	curl
	# Optional Stuff
	sudo
	vim-tiny
	build-essential
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

echo -n 'revive' >"${STAGE}/etc/hostname"

chr () { chroot "${STAGE}" "$@" || return $? }

chr bash -c ' \
	export DEBIAN_FRONTEND=noninteractive && \
	dpkg --add-architecture i386 && \
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y libc6:i386 libstdc\+\+6:i386 zlib1g:i386'

chr bash -c ' \
	export PATH=${PATH:+${PATH}:}/usr/sbin && \
	groupadd -g 1001 ubuntu && \
	useradd -s /usr/bin/bash -m -G sudo -u 1001 -g 1001 ubuntu && \
	<<<"ubuntu:ubuntu" chpasswd'

&>/dev/null mkdir -p "${STAGE}/home/ubuntu/epocroot"
chr bash -c 'chown ubuntu:ubuntu /home/ubuntu/epocroot'

cat >"${STAGE}/home/ubuntu/.bashrc" <<'.'

# SymbianRevive {{{

export EPOCROOT=${HOME}/epocroot
export PATH=${PATH:+${PATH}:}${EPOCROOT}/epoc32/tools/sbs/bin:${EPOCROOT}/epoc32/tools

export SBS_GCCE1210BIN=${EPOCROOT}/epoc32/tools/gcce-12.1.0/bin
export SBS_GCCE463BIN=${EPOCROOT}/epoc32/tools/gcce-4.6.3/bin

export SBS_GCCX86BIN=/usr/bin
export SBS_GCCX86INC=/usr/include
export SBS_GCCX86LIB=/usr/lib/x86_64-linux-gnu

export SBS_SHELL=/usr/bin/bash
export SBS_HOME=${EPOCROOT}/epoc32/tools/sbs

# }}} SymbianRevive
.

&>/dev/null mkdir -p "${STAGE}/etc/systemd/network"

cat >"${STAGE}/etc/systemd/network/50-dhcp.network" <<.
# Enable DHCP on all Ethernet ports
[Match]
Name=en*

[Network]
DHCP=yes
# vim: ft=systemd :
.
systemctl --root="${STAGE}" enable 'systemd-networkd.service'

for m in /proc /sys /dev ; do
	mount --rbind "$m" "${STAGE}$m"
	mount --make-rslave "${STAGE}$m"
done

mount --bind /var/empty "${STAGE}/sys/firmware/efi/efivars"
# NOTE: this would be REALLY (or at least a bit) unsafe if we didn't bind
#        /var/empty on /sys/firmware/efi/efivars right beforehand!
chr bash -c 'bootctl install --graceful --quiet && [[ "$(bootctl is-installed)" = yes ]]'

echo "LABEL=\"$(blkid -s LABEL -o value "${_parts[2]}")\" / ext4 rw,noatime 0 0" >>"${STAGE}/etc/fstab"
echo "LABEL=\"$(blkid -s LABEL -o value "${_parts[1]}")\" /boot/efi vfat rw,noatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro 0 0" >>"${STAGE}/etc/fstab"
echo '' >>"${STAGE}/etc/fstab"
echo 'LABEL="EPOCROOT" /home/ubuntu/epocroot ext4 rw,relatime,X-mount.idmap=b:0:1001:1 0 0' >>"${STAGE}/etc/fstab"

chr bash -c 'export PATH=${PATH:+${PATH}:}/usr/sbin && update-initramfs -u'

>&2 echo 'fstab:'
>&2 cat "${STAGE}/etc/fstab"

find "${STAGE}/boot/efi/loader/entries" -name \*.conf -exec \
	sed -i -re 's/^options.*/options ro noresume root=LABEL="Linux"/' '{}' \;
