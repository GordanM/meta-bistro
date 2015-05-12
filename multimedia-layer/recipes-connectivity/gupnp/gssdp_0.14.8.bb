#
#   Copyright (C) 2015 Pelagicore AB
#   All rights reserved.
#
require recipes-connectivity/gupnp/gssdp.inc

inherit gtk-doc

SRC_URI = "http://download.gnome.org/sources/${BPN}/0.14/${BPN}-${PV}.tar.xz"

SRC_URI[md5sum] = "b8658e480d047caf2d92baa4a51b9ae7"
SRC_URI[sha256sum] = "4c3ffa01435e84dc31c954e669e1ca0749b962f76a333e74f5c2cb0de5803a13"

EXTRA_OECONF = "--disable-gtk-doc"

DEFAULT_PREFERENCE = "-1"
