#!/bin/bash
set -x

export OPENWRT_HOME="/mnt/openwrt"

function cleanup() {
	if [ -f /swapfile ]; then
		sudo swapoff /swapfile
		sudo rm -rf /swapfile
	fi
	df -h
	sudo rm -rf /etc/apt/sources.list.d/* \
	/usr/share/dotnet \
	/usr/local/lib/android \
	/opt/hostedtoolcache/CodeQL \
	/usr/local/.ghcup \
	/usr/share/swift \
	/usr/local/lib/node_modules \
	/usr/local/share/powershell \
	/opt/ghc /usr/local/lib/heroku
	command -v docker && docker rmi $(docker images -q)
	sudo apt-get -y purge \
		azure-cli* \
		ghc* \
		zulu* \
		hhvm* \
		llvm* \
		firefox* \
		google* \
		dotnet* \
		openjdk* \
		mysql* \
		php*
	sudo apt autoremove --purge -y
	df -h
}

function init() {
	[ -f sources.list ] && (
		sudo cp -rf sources.list /etc/apt/sources.list
		sudo rm -rf /etc/apt/sources.list.d/* /var/lib/apt/lists/*
		sudo apt-get clean all
	)
	sudo apt-get update
	# sudo apt-get dist-upgrade -y
	sudo apt-get -y install ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
		bzip2 ccache cmake cpio curl device-tree-compiler fastjar flex gawk gettext gcc-multilib g++-multilib \
		git gperf haveged help2man intltool libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev \
		libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev libreadline-dev libssl-dev libtool lrzsz \
		mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python2.7 python3 python3-pyelftools \
		libpython3-dev qemu-utils rsync scons squashfs-tools subversion swig texinfo uglifyjs upx-ucl unzip \
		vim wget xmlto xxd zlib1g-dev
	sudo timedatectl set-timezone Asia/Shanghai
	git config --global user.name "GitHub Action"
	git config --global user.email "action@github.com"
}

function build() {
	release_tag="$(date +%Y-%m-%d)"
	[ -d ./files/etc/config ] || mkdir -p ./files/etc/config
	echo ${release_tag} >./files/etc/config/version

	if [ -d openwrt ]; then
		pushd openwrt
		git pull
		popd
	else
		git clone https://github.com/openwrt/openwrt.git ./openwrt
		# git clone https://github.com/coolsnowwolf/lede.git ./openwrt
		[ -f ./feeds.conf.default ] && cat ./feeds.conf.default >>./openwrt/feeds.conf.default
	fi
	pushd openwrt

	[ -d ./package/luci-app-openclash ] || git clone --depth=1 https://github.com/vernesong/OpenClash.git ./package/luci-app-openclash

	./scripts/feeds update -a
	./scripts/feeds install -a
	if [ -d ../patches ]; then
		git apply --check ../patches/*.patch
		if [ $? -eq 0 ]; then
			git am ../patches/*.patch
		fi
	fi
	[ -d ../files ] && cp -fr ../files ./files
	[ -f ../config ] && cp -fr ../config ./.config
	make defconfig
	make download -j$(nproc)
	df -h
	make -j$(nproc)
	if [ $? -ne 0 ]; then
		make -j1 V=s
	fi
	df -h
	popd
}

function artifact() {
	mkdir -p ./openwrt-r2s-squashfs-img
	ls -hl ./openwrt/bin/targets/rockchip/armv8
	cp ./openwrt/bin/targets/rockchip/armv8/*-squashfs-sysupgrade.img.gz ./openwrt-r2s-squashfs-img/
	cp ./openwrt/bin/targets/rockchip/armv8/config.buildinfo ./openwrt-r2s-squashfs-img/
	zip -r openwrt-r2s-squashfs-img.zip ./openwrt-r2s-squashfs-img
}

function auto() {
	cleanup
	init
	build
	artifact
}

$@
