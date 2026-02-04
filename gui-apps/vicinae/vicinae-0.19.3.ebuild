# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake desktop systemd unpacker

DESCRIPTION="A focused launcher for your desktop — native, fast, extensible"
HOMEPAGE="https://github.com/vicinaehq/vicinae"

SRC_URI="https://github.com/vicinaehq/vicinae/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

VERSION_GIT_HASH="d2f38c2b1fff24c4aba5bb0ea2c2bddd4ea5a5df"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+typescript-extensions lto static systemd"

# --- dependencies ------------------------------------------------
DEPEND="dev-libs/protobuf"

RDEPEND="
	${DEPEND}
	systemd? ( sys-apps/systemd )
"

BDEPEND="
	dev-libs/qtkeychain
	dev-qt/qtbase
	sys-libs/minizip-ng
	sys-libs/zlib[minizip]
	dev-cpp/rapidfuzz-cpp
	kde-plasma/layer-shell-qt
	sci-libs/libqalculate
	net-libs/nodejs[npm]
	dev-build/cmake
	app-text/cmark-gfm
	dev-qt/qtsvg
	dev-build/ninja
	dev-libs/icu
	>=sys-devel/gcc-15
	>=dev-cpp/glaze-6
"

# --- restrictions ------------------------------------------------
RESTRICT="network-sandbox"

PATCHES=() # All disabled because I figured out a way to do it without patching the fuck out of it.
# ------------------------------------------------------
# Prepare sources disable if doesn't build anymore.
# ------------------------------------------------------
src_prepare() {
	cmake_src_prepare || die "preparing the source was unsuccessful."
}

# --- configure cmake ---------------------------------------------
src_configure() {
	# Force the use of gcc 15
	if [[ "$("${CC:-gcc}" -dumpversion)" -lt "15" ]]; then
    	elog "gcc version lower than 15 detected, forcing the use of gcc 15..."
   		export CC="/usr/bin/gcc-15"
    	export CXX="/usr/bin/g++-15"
	fi

	ts_modules=("api" "extension-manager")
	for tsmodule in "${ts_modules[@]}"; do
  		pushd "typescript/$tsmodule" >/dev/null || exit 1
    	elog "installing node modules for typescript module "$tsmodule""
    	npm ci
    	popd >/dev/null || exit 1
		done

	cmake -G Ninja -B build \
		"-DPREFER_STATIC_LIBS=$(usex "static" "ON" "OFF")" \
		"-DLTO=$(usex "lto" "ON" "OFF")" \
		"-DINSTALL_NODE_MODULES=OFF" \
		"-DVICINAE_GIT_TAG=v$PV" \
		"-DVICINAE_GIT_COMMIT_HASH=$VERSION_GIT_HASH" \
		"-DVICINAE_PROVENANCE=ebuild" \
		"-DUSE_SYSTEM_GLAZE=ON" \
		"-DCMAKE_BUILD_TYPE=Release" \
		"-DTYPESCRIPT_EXTENSIONS=$(usex "typescript-extensions" "ON" "OFF")" \
		"-DCMAKE_INSTALL_PREFIX=${D}/usr" \
		"-DINSTALL_BROWSER_NATIVE_HOST=OFF" \
		|| die "couldn't configure source"
}

# --- compile -----------------------------------------------------
src_compile() {
	cmake --build build || die "cmake build was unsuccessfull..."
}


# --- install files ------------------------------------------------
src_install() {
	domenu extra/vicinae.desktop

	# --- systemd use flag -----------------------------------------
	if use systemd; then
	systemd_dounit extra/vicinae.service
	fi

	cmake --install build || die "cmake install failed"
}
