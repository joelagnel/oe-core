DESCRIPTION = "A standalone native ldconfig build"

LICENSE = "GPLv2.1"

LIC_FILES_CHKSUM = "file://${S}/ldconfig.c;endline=17;md5=1d15f20937c055cb5de2329a4c054399"

SRC_URI = "file://ldconfig-native-2.12.1.tar.bz2 \
           file://ldconfig.patch \
           file://ldconfig_aux-cache_path_fix.patch \
           file://32and64bit.patch \
           file://endian-ness_handling.patch \
           file://flag_fix.patch \
           file://endianess-header.patch"

PR = "r1"

inherit native

S = "${WORKDIR}/${PN}-${PV}"

do_compile () {
	$CC ldconfig.c -std=gnu99 chroot_canon.c xmalloc.c xstrdup.c cache.c readlib.c  -I. dl-cache.c -o ldconfig
}

do_install () {
	install -d ${D}/${bindir}/
	install ldconfig ${D}/${bindir}/
}
