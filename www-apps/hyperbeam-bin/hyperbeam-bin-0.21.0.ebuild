# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit xdg

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
	fperms +x "${appdir}/hyperbeam"
	fperms +x "${appdir}/AppRun"
	fperms +x "${appdir}/resources/vendor/Hyperbeam_Proxy"
	fperms 4755 "${appdir}/chrome-sandbox"

	local lib
	for lib in \
		libEGL.so \
		libffmpeg.so \
		libGLESv2.so \
		libvk_swiftshader.so \
		libvulkan.so.1 \
		swiftshader/libEGL.so \
		swiftshader/libGLESv2.so
	do
		[[ -f "${ED}${appdir}/${lib}" ]] && fperms +x "${appdir}/${lib}"
	done

	local usrlib
	for usrlib in \
		libappindicator.so.1 \
		libgconf-2.so.4 \
		libindicator.so.7 \
		libnotify.so.4 \
		libXss.so.1 \
		libXtst.so.6
	do
		[[ -f "${ED}${appdir}/usr/lib/${usrlib}" ]] && \
			fperms +x "${appdir}/usr/lib/${usrlib}"
	done

	dosym "${appdir}/hyperbeam" /usr/bin/hyperbeam

	# Patch + install top-level desktop file
	if [[ -f squashfs-root/hyperbeam.desktop ]]; then
		sed -i 's|^Exec=.*|Exec=/usr/bin/hyperbeam %U|' \
			squashfs-root/hyperbeam.desktop
		insinto /usr/share/applications
		doins squashfs-root/hyperbeam.desktop
	fi

	# Install icons
	local icon_src="squashfs-root/resources/assets/icons/png"

	if [[ -d "${icon_src}" ]]; then
	local size
	for size in 16 32 48 64 128 256 512; do
		if [[ -f "${icon_src}/${size}x${size}.png" ]]; then
			insinto /usr/share/icons/hicolor/${size}x${size}/apps
			newins "${icon_src}/${size}x${size}.png" hyperbeam.png
		fi
	done
	fi
}

pkg_postinst() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_icon_cache_update
	xdg_desktop_database_update
}
