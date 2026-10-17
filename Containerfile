ARG jobs
ARG packages

FROM docker.io/library/ubuntu:24.04 AS base

RUN set -eu && \
	export DEBIAN_FRONTEND=noninteractive && \
	dpkg --add-architecture i386 && \
	printf 'deb http://archive.ubuntu.com/ubuntu/ resolute main\n' \
		>/etc/apt/sources.list.d/resolute.list && \
	printf 'Package: *\nPin: release n=resolute*\nPin-Priority: -10\n\nPackage: libfuse3-dev\nPin: release n=resolute*\nPin-Priority: 990\n\nPackage: libfuse3-4\nPin: release n=resolute*\nPin-Priority: 990\n\nPackage: fuse3\nPin: release n=resolute*\nPin-Priority: 990\n' \
    >/etc/apt/preferences.d/resolute-pins &&\
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install --no-install-recommends -y \
		bash zsh passwd sudo build-essential gcc-multilib g++-multilib \
		automake autoconf python3 python-is-python3 perl gawk lz4 curl \
		pkg-config ca-certificates fuse3 libfuse3-4 libc6-dev libgmp10 \
		libmpfr6 libmpc3 libicu74 libc6-dev:i386 zlib1g-dev:i386

RUN set -eu && \
	ln -fs /proc/mounts /etc/mtab && \
	useradd -s /usr/bin/zsh -mG sudo carla && \
	install -o carla -g carla -m 0644 /dev/null /home/carla/.zshrc && \
	printf 'Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"\n\nroot ALL=(ALL:ALL) ALL\n%sudo ALL=(ALL:ALL) NOPASSWD: ALL\ncarla ALL=(ALL:ALL) NOPASSWD: ALL\n' \
		>/etc/sudoers && \
	visudo -c

FROM base AS build

ENV jobs=${jobs}
ENV packages=${packages}

RUN set -eu && \
	export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install --no-install-recommends -y \
		parallel moreutils clang git wget aria2 \
		libgmp-dev libmpfr-dev libmpc-dev libfuse3-dev libicu-dev

USER carla

COPY . /home/carla/src/epocstrap
WORKDIR /home/carla/src/epocstrap

ENV EPOCROOT=/home/carla/epocroot

RUN set -eu && \
	bin/epocstrap -j"${jobs:-11}" ${packages:-modern-gcc}

FROM base

USER carla

ENV EPOCROOT=/home/carla/epocroot

COPY --from=build ${EPOCROOT} ${EPOCROOT}

COPY ./extras/docker_wrapper.zsh /usr/local/bin/

WORKDIR /home/carla

ENTRYPOINT ["/usr/local/bin/docker_wrapper.zsh"]

CMD ["/usr/bin/zsh"]
