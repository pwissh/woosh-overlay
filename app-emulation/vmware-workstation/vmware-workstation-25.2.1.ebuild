# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit readme.gentoo-r1 xdg-utils

### These are my most complicated ebuild packages to this day so we'll take some notes
### in order to make it easier for me to maintain it in the future, yeah? Yeah.

# MY_PV is the real upstream version string used in bundle filenames and URLs.
# PV (25.2.1) is the Portage-sanitised version (no uppercase/mixed alnum).
# Mapping: 25=year, H2=second half, u1=update 1 → 25.2.1
MY_PV="25H2u1"

# Broadcom's internal build number, embedded in the bundle filename.
# Update this alongside MY_PV when upgrading
_BUILDVER="25219725"

MY_BUNDLE="VMware-Workstation-Full-${MY_PV}-${_BUILDVER}.x86_64.bundle"

DESCRIPTION="The industry standard for running multiple operating systems as virtual machines"
HOMEPAGE="https://www.vmware.com/products/workstation-for-linux.html"
SRC_URI="
	amd64? ( https://archive.org/download/VMware-Workstation-Full-${MY_PV}-${_BUILDVER}.x86_64/${MY_BUNDLE} )
	https://packages-prod.broadcom.com/tools/frozen/linux/linux.iso
	https://packages-prod.broadcom.com/tools/frozen/linux/linuxPreGlibc25.iso
	https://packages-prod.broadcom.com/tools/frozen/netware/netware.iso
	https://packages-prod.broadcom.com/tools/frozen/solaris/solaris.iso
	https://packages-prod.broadcom.com/tools/frozen/windows/winPre2k.iso
	https://packages-prod.broadcom.com/tools/frozen/windows/winPreVista.iso
"

# I will manage unpacking manually in src_unpack
S="${WORKDIR}"

LICENSE="vmware"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE=""

# Portage must not strip prebuilt VMware binaries — they use their own
# internal RPATHs and stripping will break them pretty bad
RESTRICT="strip mirror"

RDEPEND="
	acct-group/vmware
	app-emulation/vmware-host-modules
	dev-libs/glib:2
	dev-libs/libaio
	dev-libs/openssl:=
	gnome-base/librsvg
	media-libs/libpulse
	net-libs/libtirpc
	sys-apps/pcsc-lite
	sys-fs/fuse:0
	virtual/libcrypt:=
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXi
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXtst
"

DEPEND="${RDEPEND}"

BDEPEND="
	dev-db/sqlite
"

# Suppress QA warnings about prebuilt binaries with non-standard RPATHs,
# unresolved sonames, etc. — all expected for a bundled proprietary package
QA_PREBUILT="*"

src_unpack() {
	local bundle="${DISTDIR}/${MY_BUNDLE}"
	[[ -f "${bundle}" ]] || die "Bundle not found in DISTDIR: ${MY_BUNDLE}"

	# The bundle is a self-extracting binary shell archive — it must be
	# marked executable before it can be run. DISTDIR is read-only so
	# copy it to WORKDIR first
	cp "${bundle}" "${WORKDIR}/${MY_BUNDLE}" || die
	chmod +x "${WORKDIR}/${MY_BUNDLE}" || die

	einfo "Extracting VMware bundle (this takes a moment)..."
	"${WORKDIR}/${MY_BUNDLE}" --extract "${WORKDIR}/extracted" \
		|| die "Failed to extract bundle"
}

src_install() {
	local extracted="${WORKDIR}/extracted"

	# Read the installer version from the bundle's manifest so it can
	# install the installer component to the correct versioned path
	local vmware_installer_version
	vmware_installer_version=$(grep -oPm1 '(?<=<version>)[^<]+' \
		"${extracted}/vmware-installer/manifest.xml") || die

	# Suppress automatic compression of man pages — VMware ships them
	# pre-compressed and double-compression would corrupt them
	docompress -x /usr/share/man

	# --- Core directories ---
	dodir \
		/etc/{modprobe.d,vmware,vmware-installer,vmware-vix} \
		/usr/{bin,share} \
		/usr/include/vmware-vix \
		/usr/lib/{vmware/setup,vmware/modules,vmware-vix,vmware-ovftool} \
		/usr/lib/vmware-installer/"${vmware_installer_version}" \
		/usr/share/{doc/vmware-vix,licenses/${PN}}

	# keepdir so portage preserves this directory even though it starts empty
	keepdir /var/lib/vmware

	cd "${extracted}" || die

	# --- Share / man ---
	cp -r vmware-workstation/share/* \
		vmware-network-editor-ui/share/* \
		vmware-player-app/share/* \
		"${ED}/usr/share" || die
	cp -r vmware-workstation/man "${ED}/usr/share" || die

	# --- Binaries ---
	# Note: vmware-vmx/sbin contains vmware-authd
	cp -r vmware-workstation/bin/* \
		vmware-vmx/bin/* \
		vmware-vmx/sbin/* \
		vmware-vix-core/bin/* \
		vmware-vprobe/bin/* \
		vmware-player-app/bin/* \
		"${ED}/usr/bin" || die

	# vmware-usbarbitrator is a standalone binary — install directly to
	# /usr/bin, not into the vmware lib dir
	dobin vmware-usbarbitrator/bin/vmware-usbarbitrator

	# --- Libraries ---
	cp -r vmware-workstation/lib/* \
		vmware-player-app/lib/* \
		vmware-vmx/lib/* \
		vmware-vmx/roms \
		vmware-vprobe/lib/* \
		vmware-network-editor/lib/* \
		"${ED}/usr/lib/vmware" || die

	cp -r vmware-player-setup/vmware-config \
		"${ED}/usr/lib/vmware/setup" || die

	# modules.xml moved to vmware-vmx/extra/ in 25H2 (was in lib/modules/)
	insinto /usr/lib/vmware/modules
	doins vmware-vmx/extra/modules.xml

	# Module sources are managed by app-emulation/vmware-host-modules
	rm -rf "${ED}/usr/lib/vmware/modules/source" 2>/dev/null

	# --- VIX ---
	# vix-core/lib contains libvixAllProducts.so and a setup/ subdir
	cp -r vmware-vix-lib-Workstation1700/lib/Workstation-17.0.0 \
		vmware-vix-core/lib/setup \
		"${ED}/usr/lib/vmware-vix" || die
	# Install the shared library properly so ldconfig can find it
	dolib.so vmware-vix-core/lib/libvixAllProducts.so
	insinto /usr/lib/vmware-vix
	doins vmware-vix-core/vixwrapper-config.txt
	cp -r vmware-vix-core/doc/* "${ED}/usr/share/doc/vmware-vix" || die
	insinto /usr/include/vmware-vix
	doins vmware-vix-core/include/* || die

	# --- ovftool ---
	cp -r vmware-ovftool/* "${ED}/usr/lib/vmware-ovftool" || die
	# These are either duplicated elsewhere or unused
	rm "${ED}/usr/lib/vmware-ovftool"/{vmware-eula.rtf,open_source_licenses.txt,manifest.xml} \
		|| die

	# --- VMware installer component ---
	# Kept for compatibility with any post-install scripts that invoke it.
	# The bundled Python lib-dynload .so files use $$ORIGIN in their RPATH
	# which causes portage's ELF scanner to spam "$: bad substitution" errors
	# during ld.so.cache regeneration — and they're never used in a packaged
	# install anyway, so remove them.
	cp -r \
		vmware-installer/python \
		vmware-installer/sopython \
		vmware-installer/vmis \
		vmware-installer/vmis-launcher \
		vmware-installer/vmware-installer \
		vmware-installer/vmware-installer.py \
		"${ED}/usr/lib/vmware-installer/${vmware_installer_version}" || die
	rm -rf "${ED}/usr/lib/vmware-installer/${vmware_installer_version}/python/lib/lib-dynload" || die

	# --- ISO images (guest tools) ---
	# Fetched separately from Broadcom's CDN in SRC_URI
	insinto /usr/lib/vmware/isoimages
	for img in linux linuxPreGlibc25 netware solaris winPre2k winPreVista; do
		doins "${DISTDIR}/${img}.iso"
	done
	# Windows guest tools are embedded in the bundle itself
	doins vmware-tools-windows/windows.iso

	# --- Licenses ---
	insinto /usr/share/doc/vmware-workstation
	doins vmware-workstation/doc/EULA
	dosym /usr/share/doc/vmware-workstation/EULA \
		"/usr/share/licenses/${PN}/VMware Workstation - EULA.txt"
	dosym /usr/lib/vmware-ovftool/vmware.eula \
		"/usr/share/licenses/${PN}/VMware OVF Tool - EULA.txt"
	insinto "/usr/share/licenses/${PN}"
	doins vmware-workstation/doc/open_source_licenses.txt
	doins vmware-workstation/doc/ovftool_open_source_licenses.txt

	# --- Fix permissions ---
	# The bundle ships many executables as non-executable (644) — fix them all.
	# Do this before fperms calls so suid bits are applied last and not lost.
	find "${ED}/usr/bin" -type f -exec chmod 755 {} +
	find "${ED}/usr/lib/vmware/bin" -type f -exec chmod 755 {} +
	find "${ED}/usr/lib/vmware/lib" -type f -name "*.so*" -exec chmod 755 {} +
	find "${ED}/usr/lib/vmware-installer" -type f \
		\( -name "*.py" -o ! -name "*.*" \) -exec chmod 755 {} +

	# vmware-authd uses privilege separation and needs suid
	fperms 4711 /usr/bin/vmware-authd

	# vmx binaries need suid to open /dev/vmmon
	for f in vmware-vmx vmware-vmx-debug vmware-vmx-stats; do
		[[ -f "${ED}/usr/lib/vmware/bin/${f}" ]] \
			&& fperms 4711 "/usr/lib/vmware/bin/${f}"
	done

	# --- Symlinks the installer would normally create ---
	# appLoader is a multiplexer binary that dispatches to the real binary
	local apploader_links=(
		licenseTool vmplayer vmware vmware-app-control vmware-enter-serial
		vmware-fuseUI vmware-gksu vmware-modconfig vmware-modconfig-console
		vmware-mount vmware-netcfg vmware-setup-helper vmware-tray
		vmware-vmblock-fuse vmware-vprobe vmware-zenity
	)
	for link in "${apploader_links[@]}"; do
		dosym /usr/lib/vmware/bin/appLoader "/usr/lib/vmware/bin/${link}"
	done
	# Note: vmware-usbarbitrator is NOT in this loop — it's a real binary
	# installed by dobin above, not an appLoader symlink
	for link in vmware-fuseUI vmware-mount vmware-netcfg; do
		dosym "/usr/lib/vmware/bin/${link}" "/usr/bin/${link}"
	done
	dosym /usr/lib/vmware/bin/appLoader /usr/bin/vmrest
	dosym /usr/lib/vmware-ovftool/ovftool /usr/bin/ovftool
	# Use a relative symlink (absolute symlinks in lib dirs trigger QA warnings)
	dosym ../vmware-vix/libvixAllProducts.so /usr/lib/libvixAllProducts.so
	dosym /usr/lib/vmware/icu /etc/vmware/icu

	# --- Fix placeholder variables in installed files ---
	sed -i 's,@@LIBCONF_DIR@@,/usr/lib/vmware/libconf,g' \
		"${ED}/usr/lib/vmware/libconf/etc/gtk-3.0/gdk-pixbuf.loaders" || die
	sed -i 's,@@BINARY@@,/usr/bin/vmware,' \
		"${ED}/usr/share/applications/vmware-workstation.desktop" || die
	sed -i 's,@@BINARY@@,/usr/bin/vmplayer,' \
		"${ED}/usr/share/applications/vmware-player.desktop" || die
	sed -i 's,@@BINARY@@,/usr/bin/vmware-netcfg,' \
		"${ED}/usr/share/applications/vmware-netcfg.desktop" || die

	# Patch out the modconfig gcc check at startup — vmware-modconfig always
	# fails on non-standard setups (Clang kernels, custom overlays, etc.)
	# so we will manage modules ourselves via app-emulation/vmware-host-modules
	for program in vmware vmplayer vmware-tray; do
		[[ -f "${ED}/usr/bin/${program}" ]] || continue
		sed -e 's/if "$BINDIR"\/vmware-modconfig --appname=.*/if true ||/' \
			-i "${ED}/usr/bin/${program}" || die
	done

	# Force VMware to use XWayland when running under a Wayland compositor.
	# VMware's bundled GTK cannot speak the Wayland protocol directly and
	# will silently fail to open a window without this.
	for program in vmware vmplayer; do
		[[ -f "${ED}/usr/bin/${program}" ]] || continue
		sed -i '2a export GDK_BACKEND=x11' \
			"${ED}/usr/bin/${program}" || die
	done

	# --- Desktop file tweaks ---
	sed -i '/^StartupNotify=.*/a StartupWMClass=vmware' \
		"${ED}/usr/share/applications/vmware-workstation.desktop" || die
	sed -i '/^StartupNotify=.*/a StartupWMClass=vmplayer' \
		"${ED}/usr/share/applications/vmware-player.desktop" || die

	# --- modprobe config (vmware-fuse) ---
	insinto /etc/modprobe.d
	doins vmware-vmx/etc/modprobe.d/modprobe-vmware-fuse.conf

	# --- Static config files ---
	# These are normally generated by VMware's own installer. I will ship static
	# versions from files/ since I bypass the installer entirely.
	# Dynamic fields (telemetryUUID, epoch timestamps) are intentionally
	# omitted — VMware regenerates them at first run.
	# Note: config has acceptEULA = "yes" pre-set — see EULA note in pkg_postinst
	insinto /etc/vmware
	newins "${FILESDIR}/vmware-bootstrap" bootstrap
	doins "${FILESDIR}/config"

	insinto /etc/vmware-vix
	newins "${FILESDIR}/vmware-vix-bootstrap" bootstrap

	# The installer bootstrap is taken from the bundle and then patched
	# to substitute the @@VERSION@@ and @@VMWARE_INSTALLER@@ placeholders
	insinto /etc/vmware-installer
	doins vmware-installer/bootstrap
	sed -e "s/@@VERSION@@/${vmware_installer_version}/" \
		-e "s,@@VMWARE_INSTALLER@@,/usr/lib/vmware-installer/${vmware_installer_version}," \
		-i "${ED}/etc/vmware-installer/bootstrap" || die

	# --- OpenRC service ---
	newconfd "${FILESDIR}/vmware.confd" vmware
	newinitd "${FILESDIR}/vmware.initd" vmware

	local DISABLE_AUTOFORMATTING=yes
	local DOC_CONTENTS="
To use VMware as a regular user, add yourself to the 'vmware' group:
  gpasswd -a YOUR_USER vmware
Then log out and back in (or: newgrp vmware).

Kernel modules are provided by app-emulation/vmware-host-modules.
After every kernel upgrade, rebuild them with:
  emerge @module-rebuild

Start VMware services at boot:
  rc-service vmware start
  rc-update add vmware default
"
	readme.gentoo_create_doc
}

pkg_postinst() {
	readme.gentoo_print_elog
	xdg_desktop_database_update
	xdg_icon_cache_update

	# Create the VMware installer database that VMware checks at startup
	# to verify its components are registered. Without this VMware silently
	# exits immediately on first launch.
	if [[ ! -f "${EROOT}/etc/vmware-installer/database" ]]; then
		einfo "Creating VMware installer database..."
		sqlite3 "${EROOT}/etc/vmware-installer/database" \
			"CREATE TABLE settings(key VARCHAR PRIMARY KEY, value VARCHAR NOT NULL, component_name VARCHAR NOT NULL);" || die
		sqlite3 "${EROOT}/etc/vmware-installer/database" \
			"INSERT INTO settings(key,value,component_name) VALUES('db.schemaVersion','2','vmware-installer');" || die
		sqlite3 "${EROOT}/etc/vmware-installer/database" \
			"CREATE TABLE components(id INTEGER PRIMARY KEY, name VARCHAR NOT NULL, version VARCHAR NOT NULL, buildNumber INTEGER NOT NULL, component_core_id INTEGER NOT NULL, longName VARCHAR NOT NULL, description VARCHAR, type INTEGER NOT NULL);" || die
		sqlite3 "${EROOT}/etc/vmware-installer/database" \
			"INSERT INTO components(name,version,buildNumber,component_core_id,longName,description,type) VALUES('vmware-workstation','${MY_PV}',${_BUILDVER},1,'VMware Workstation','VMware Workstation',1);" || die
	fi

	# Note: the EULA is pre-accepted in files/config (acceptEULA = "yes").
	# By installing and using this package you are agreeing to VMware's EULA.
	# The full text is at /usr/share/doc/vmware-workstation/EULA

	if [[ -z $(getent group vmware | cut -d: -f4) ]]; then
		ewarn "The 'vmware' group has no members yet."
		ewarn "To use VMware as a regular user:"
		ewarn "  gpasswd -a YOUR_USER vmware"
	fi
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
