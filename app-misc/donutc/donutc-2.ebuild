# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Donut-shaped C code that outputs a 3D spinning donut"
HOMEPAGE="https://www.a1k0n.net/2021/01/13/optimizing-donut.html"
SRC_URI=""

LICENSE=""
SLOT="0"
KEYWORDS="*"
IUSE="+gcc clang"

REQUIRED_USE="^^ ( gcc clang )"

DEPEND=""
RDEPEND="${DEPEND}"
BDEPEND=""

S="${WORKDIR}"

src_unpack() {
	cp "${FILESDIR}/donut.c" "${WORKDIR}" || die
}

src_compile() {

	if use clang; then
		export CC=clang
	else
	    export CC=gcc
	fi

	${CC} \
		-Wno-implicit-function-declaration \
		-Wno-implicit-int \
		-Wno-builtin-declaration-mismatch \
		-w \
		donut.c \
		-o donutc || die
}

src_install() {
	dobin donutc
}
