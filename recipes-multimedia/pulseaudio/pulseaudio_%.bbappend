#
#   Copyright (C) 2015 Pelagicore AB
#   All rights reserved.
#
DEPENDS := "${@oe_filter_out('gconf', '${DEPENDS}', d)}"
EXTRA_OECONF += " --disable-gconf "

RDEPENDS_pulseaudio-server += " \
    pulseaudio-misc \
    pulseaudio-module-bluetooth-discover \
    pulseaudio-module-bluetooth-policy \
"

SRC_URI += "file://pulseaudio-mutex-assert-fix.patch"

FILESEXTRAPATHS_prepend := "${THISDIR}/${PN}:"
