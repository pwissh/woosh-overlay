# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Script to migrate from split-usr to merged-usr"
HOMEPAGE="https://gitlab.com/pwish/merge-usr-bash"
SRC_URI="https://gitlab.com/pwish/merge-usr-bash/-/archive/${PV}/merge-usr-bash-${PV}.tar.gz"

S="${WORKDIR}/merge-usr-bash-${PV}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86"

src_install() {
	newbin merge-usr.sh merge-usr
}
