# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Hyperbeam shared browser and streaming virtual machine"
HOMEPAGE="https://hyperbeam.com"
SRC_URI="https://cdn.hyperbeam.com/Hyperbeam-${PV}.AppImage -> ${P}.AppImage"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="strip mirror bindist"
QA_PREBUILT="opt/${PN%-bin}/*"

DEPEND=""
RDEPEND=""
BDEPEND=""
S="${WORKDIR}"

src_unpack() {
	cp "${DISTDIR}/${P}.AppImage" hyperbeam.AppImage || die
	chmod +x hyperbeam.AppImage || die
	./hyperbeam.AppImage --appimage-extract || die
}

src_prepare() {
	default

	# Patch out the internal xdg.desktop template for valid runtime .desktop
	rm -f squashfs-root/resources/assets/xdg.desktop \
		|| die "Failed to remove xdg.desktop template"

}

src_install() {
	local appdir="/opt/${PN%-bin}"

	# Install full AppImage contents
	insinto "${appdir}"
	doins -r squashfs-root/*

	# Ensure main executable is executable and symlink to /usr/bin
	if [[ -f "${ED}${appdir}/hyperbeam" ]]; then
		fperms +x "${appdir}/hyperbeam"
		dosym "${appdir}/hyperbeam" /usr/bin/hyperbeam
	fi

	# Patch + install top-level desktop file
	if [[ -f squashfs-root/hyperbeam.desktop ]]; then
		sed -i 's|^Exec=.*|Exec=/usr/bin/hyperbeam %U|' \
			squashfs-root/hyperbeam.desktop
		insinto /usr/share/applications
		doins squashfs-root/hyperbeam.desktop
	fi

	# Install icons
	if [[ -d squashfs-root/usr/share/icons ]]; then
		insinto /usr/share/icons
		doins -r squashfs-root/usr/share/icons/*
	fi
}
