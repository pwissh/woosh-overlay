EAPI=8

inherit cmake

MY_PV="${PV/_alpha/-alpha.}"
MY_PV="${MY_PV/_rc/-rc.}"

DESCRIPTION="AirPods liberated from Apple's ecosystem"
HOMEPAGE="https://github.com/kavishdevar/librepods"
SRC_URI="https://github.com/kavishdevar/${PN}/archive/v${MY_PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/${PN}-${MY_PV}/linux"  # we'll verify this

LICENSE="AGPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"

DEPEND="dev-libs/openssl:="

RDEPEND="${DEPEND}
	dev-qt/qtbase:6[dbus,widgets]
	dev-qt/qtconnectivity:6[bluetooth]
	dev-qt/qtdeclarative:6[widgets]
	dev-qt/qtmultimedia:6[ffmpeg]
"

src_prepare() {
	cmake_src_prepare
}
