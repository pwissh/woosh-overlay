# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

### This package solely acts as a dependency to app-emulation/vmware-workstation.
### It's only job is to create a vmware group.

EAPI=8

inherit acct-group

# -1 means dynamically allocate GID (correct for overlay packages
# that are not coordinated with the central Gentoo GID registry)
ACCT_GROUP_ID=-1
