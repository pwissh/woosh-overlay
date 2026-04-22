# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop xdg git-r3

DESCRIPTION="A non-web browser, designed for a growing list of protocols (live)"
HOMEPAGE="https://bombadillo.colorfield.space/"
EGIT_REPO_URI="https://tildegit.org/sloum/bombadillo"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS=""

DEPEND=">=dev-lang/go-1.20"
RDEPEND="sys-libs/ncurses"

S="${WORKDIR}/${P}"

src_compile() {
	go build -o bombadillo
}

src_install() {
	dobin bombadillo
	doman bombadillo.1
	domenu bombadillo.desktop
	doicon bombadillo-icon.png
}

pkg_postinst() {
	xdg_desktop_database_update
}

pkg_postrm() {
	xdg_desktop_database_update
}
