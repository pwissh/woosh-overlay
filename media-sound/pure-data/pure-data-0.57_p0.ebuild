# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit autotools xdg

MY_P="pd-${PV/_p/-}"

DESCRIPTION="Pure Data: real-time music and multimedia environment"
HOMEPAGE="https://msp.ucsd.edu/software.html"
SRC_URI="https://msp.ucsd.edu/Software/${MY_P}.src.tar.gz"
S="${WORKDIR}/${MY_P}"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"

IUSE="+alsa debug experimental extra +fftw instance jack libpd nls portaudio portmidi utils +watchdog"

REQUIRED_USE="|| ( alsa jack portaudio )"

RDEPEND="
	>=dev-lang/tcl-8.6
	>=dev-lang/tk-8.6
	alsa? ( >=media-libs/alsa-lib-0.9.0_rc2 )
	jack? ( virtual/jack )
	fftw? ( sci-libs/fftw:3.0= )
	portaudio? ( media-libs/portaudio )
	portmidi? ( media-libs/portmidi )
"
DEPEND="${RDEPEND}"
BDEPEND="
	virtual/pkgconfig
	nls? ( sys-devel/gettext )
"

src_prepare() {
	default

	# keep the old Categories override, but patch the source file
	# (renamed upstream: org.puredata.pd-gui.desktop -> info.puredata.Pd.desktop)
	sed -i -e 's/^Categories=.*/Categories=AudioVideo;AudioVideoEditing;/' \
		linux/info.puredata.Pd.desktop || die

	eautoreconf
}

src_configure() {
	local myeconfargs=(
		$(use_enable alsa)
		$(use_enable debug)
		$(use_enable extra libpd-extra)
		$(use_enable fftw)
		$(use_enable instance libpd-instance)
		$(use_enable jack)
		$(use_enable libpd)
		$(use_enable nls locales)
		$(use_enable portaudio)
		$(use_enable portmidi)
		$(use_enable utils libpd-utils)
		$(use_enable watchdog)
		--disable-oss
		--without-local-portaudio
		--without-local-portmidi
	)
	use experimental && myeconfargs+=( --with-floatsize=64 )

	econf "${myeconfargs[@]}"
}

src_install() {
	default
	find "${ED}" -type f -name '*.la' -delete || die

	use watchdog && dosym "../$(get_libdir)/pd/bin/pd-watchdog" /usr/bin/pd-watchdog

	# Pd only looks for its tcl/, extra/ and bin/ in <prefix>/lib/pd,
	# so make that path resolve on lib64 systems
	if [[ $(get_libdir) != lib ]]; then
		dosym "../$(get_libdir)/pd" /usr/lib/pd
	fi
}

pkg_postinst() {
	xdg_pkg_postinst

	if use experimental; then
		ewarn "USE=experimental builds Pd with 64-bit (double precision) floats."
		ewarn "Externals use a different extension in this mode (.linux-amd64-64.so)."
		ewarn "Externals built for the normal 32-bit float Pd will not load, and"
		ewarn "externals built for this build will not load in a normal Pd."
	fi
}
