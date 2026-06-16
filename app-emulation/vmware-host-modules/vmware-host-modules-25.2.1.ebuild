# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit linux-mod-r1 readme.gentoo-r1 udev

### These are my most complicated ebuild packages to this day so we'll take some notes
### in order to make it easier for me to maintain it in the future, yeah? Yeah.

# MY_PV is the real upstream version string (see vmware-workstation ebuild)
MY_PV="25H2u1"
_BUILDVER="25219725"
MY_BUNDLE="VMware-Workstation-Full-${MY_PV}-${_BUILDVER}.x86_64.bundle"

# Pin philipl's workstation-25h2 branch to a specific commit for
# reproducibility. Branch HEAD can change at any time, breaking the
# distfile hash.
#
# To update after philipl pushes new fixes:
#   1. Get the new HEAD:
#        git ls-remote https://github.com/philipl/vmware-host-modules \
#            refs/heads/workstation-25h2
#   2. Set PHILIPL_COMMIT to the new hash below
#   3. Bump the ebuild revision (e.g. -r1 → -r2)
#   4. Run: ebuild manifest
PHILIPL_COMMIT="5c80f597017882f76e9c7ffd48a292a4b7c860fe"
PHILIPL_SHORT="${PHILIPL_COMMIT::7}"

DESCRIPTION="VMware Workstation kernel modules (vmmon + vmnet) patched for recent kernels"
HOMEPAGE="https://github.com/philipl/vmware-host-modules"
SRC_URI="
	https://archive.org/download/VMware-Workstation-Full-${MY_PV}-${_BUILDVER}.x86_64/${MY_BUNDLE}
	https://github.com/philipl/vmware-host-modules/archive/${PHILIPL_COMMIT}.tar.gz
		-> philipl-vmware-host-modules-${PHILIPL_SHORT}.tar.gz
"

# I will manage unpacking manually in src_unpack
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="-* ~amd64"

# No dependency on vmware-workstation here — that would create a circular dep
# since vmware-workstation depends on this. The bundle is fetched here solely
# to extract module sources; portage deduplicates the download since
# vmware-workstation lists the same URI.
RDEPEND="
	acct-group/vmware
"

# linux-mod-r1 sets KERNEL_CC/LD/etc. automatically by inspecting the kernel's
# own build configuration. No need to override for Clang kernels — the eclass
# detects it and picks the right toolchain (verified working with LLVM 21).
# I will need to suppress the dist-kernel version mismatch warning since this
# will build for a custom kernel (not sys-kernel/gentoo-kernel).
MODULES_KERNEL_MAX=""
MODULES_KERNEL_MIN=""

pkg_setup() {
	linux-mod-r1_pkg_setup
}

src_unpack() {
	local bundle="${DISTDIR}/${MY_BUNDLE}"
	[[ -f "${bundle}" ]] || die "Bundle not found in DISTDIR: ${MY_BUNDLE}"

	# The bundle is a self-extracting binary shell archive therefore must be
	# executable. DISTDIR is read-only so copy to WORKDIR first.
	cp "${bundle}" "${WORKDIR}/${MY_BUNDLE}" || die
	chmod +x "${WORKDIR}/${MY_BUNDLE}" || die

	einfo "Extracting VMware bundle (this takes a moment)..."
	"${WORKDIR}/${MY_BUNDLE}" --extract "${WORKDIR}/vmware-extracted" \
		|| die "Failed to extract VMware bundle"

	# philipl's tree is the already-patched source therefore no separate patches
	# are needed. It contains vmmon-only/ and vmnet-only/ ready to build.
	tar xf "${DISTDIR}/philipl-vmware-host-modules-${PHILIPL_SHORT}.tar.gz" \
		-C "${WORKDIR}" || die "Failed to unpack philipl sources"

	# The archive unpacks to vmware-host-modules-<full-hash>/ so it will rename to
	# a stable path we can reference throughout the rest of the ebuild
	mv "${WORKDIR}/vmware-host-modules-${PHILIPL_COMMIT}" \
		"${WORKDIR}/philipl" || die "Failed to rename philipl source dir"
}

src_prepare() {
	# philipl's tree is already patched — nothing to apply.
	# eapply_user runs anyway so users can layer additional patches if needed.
	eapply_user
}

src_compile() {
	local philipldir="${WORKDIR}/philipl"

	[[ -d "${philipldir}/vmmon-only" ]] \
		|| die "vmmon-only not found — check PHILIPL_COMMIT is correct"
	[[ -d "${philipldir}/vmnet-only" ]] \
		|| die "vmnet-only not found — check PHILIPL_COMMIT is correct"

	# I will drive make directly rather than using linux-mod-r1_src_compile
	# because vmmon/vmnet use their own Makefile conventions:
	#   - HEADER_DIR: where to find kernel headers (vmmon's own variable,
	#     set to KV_DIR/include to avoid the LINUXINCLUDE multi-flag issue)
	#   - VM_UNAME: kernel version string (avoids relying on uname -r which
	#     would return the "running" kernel, wrong after a kernel upgrade)
	#   - No SRCROOT: vmmon hardcodes SRCROOT=. internally; passing it from
	#     outside confuses its standalone vs kernel build system detection
	#
	# LLVM=1 LLVM_IAS=1 ARCH=x86 are required for Clang-built kernels:
	#   - LLVM=1: tells kernel's Makefile.clang to set --target= correctly
	#   - LLVM_IAS=1: use Clang's integrated assembler
	#   - ARCH=x86: sets SRCARCH=x86 → CLANG_TARGET_FLAGS=x86_64-linux-gnu
	#     (kernel 7.x requires this to be explicit for out-of-tree modules)
	#   - If you run a Clang-built kernel I love you consentually.
	local kargs=(
		-C "${KV_OUT_DIR}"
		MODULEBUILDDIR=
		CC="${KERNEL_CC}"
		LD="${KERNEL_LD}"
		LDFLAGS=""
		VM_UNAME="${KV_FULL}"
		HEADER_DIR="${KV_DIR}/include"
		ARCH=x86
	)

	if [[ "${KERNEL_CC}" == *clang* ]]; then
		kargs+=( LLVM=1 LLVM_IAS=1 )
		einfo "Detected Clang kernel toolchain — enabling LLVM=1 LLVM_IAS=1"
	fi

	einfo "Building vmmon..."
	emake "${kargs[@]}" M="${philipldir}/vmmon-only" modules \
		|| die "vmmon build failed"

	einfo "Building vmnet..."
	emake "${kargs[@]}" M="${philipldir}/vmnet-only" modules \
		|| die "vmnet build failed"
}

src_install() {
	local philipldir="${WORKDIR}/philipl"

	# Install .ko files into the misc module subdirectory
	insinto "/lib/modules/${KV_FULL}/misc"
	doins "${philipldir}/vmmon-only/vmmon.ko"
	doins "${philipldir}/vmnet-only/vmnet.ko"

	# modules_post_process: handles stripping, compression, and optional
	# signing (signing respects MODULES_SIGN_* variables from make.conf)
	modules_post_process

	# udev rules: grant vmware group rw access to /dev/vmmon and /dev/vmnet*
	# so non-root users in that group can start VMs without sudo
	udev_newrules - 99-vmware.rules <<-EOF
		KERNEL=="vmmon",  GROUP="vmware", MODE="0660"
		KERNEL=="vmnet*", GROUP="vmware", MODE="0660"
	EOF

	local DISABLE_AUTOFORMATTING=yes
	local DOC_CONTENTS="
VMware kernel modules installed for kernel ${KV_FULL}.

=== Running VMware as a regular user ===
Add yourself to the 'vmware' group:
  gpasswd -a YOUR_USER vmware
Then log out and back in (or: newgrp vmware).

=== After every kernel upgrade ===
Rebuild these modules automatically with:
  emerge @module-rebuild
The modules load at boot via /etc/modules-load.d/vmware.conf.
To load them immediately without rebooting:
  modprobe vmmon && modprobe vmnet
  rc-service vmware start
"
	readme.gentoo_create_doc
}

pkg_postinst() {
	linux-mod-r1_pkg_postinst
	udev_reload
	readme.gentoo_print_elog

	if [[ -z $(getent group vmware | cut -d: -f4) ]]; then
		ewarn "The 'vmware' group has no members yet."
		ewarn "To use VMware as a regular user:"
		ewarn "  gpasswd -a YOUR_USER vmware"
	fi

	if lsmod | grep -q vmmon; then
		ewarn "vmmon is currently loaded from a previous install."
		ewarn "Reboot or restart VMware services to use the new modules:"
		ewarn "  rc-service vmware restart"
	fi
}

pkg_postrm() {
	udev_reload

	if lsmod | grep -q vmmon; then
		einfo "Attempting to unload vmmon/vmnet after removal..."
		rmmod vmnet vmmon 2>/dev/null \
			|| ewarn "Could not unload modules — a VM may still be running."
	fi
}
