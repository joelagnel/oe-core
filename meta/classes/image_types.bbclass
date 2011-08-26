
def get_imagecmds(d):
    cmds = "\n"
    old_overrides = bb.data.getVar('OVERRIDES', d, 0)

    types = bb.data.getVar('IMAGE_FSTYPES', d, True).split()
    # Live images will be processed via inheriting bbclass and 
    # does not get processed here.
    # live images also depend on ext3 so ensure its present
    if "live" in types:
        if "ext3" not in types:
            types.append("ext3")
        types.remove("live")

    for type in types:
        localdata = bb.data.createCopy(d)
        localdata.setVar('OVERRIDES', '%s:%s' % (type, old_overrides))
        bb.data.update_data(localdata)
        localdata.setVar('type', type)
        cmd = localdata.getVar("IMAGE_CMD", True)
        localdata.setVar('cmd', cmd)
        cmds += localdata.getVar("runimagecmd", True)
    return cmds

runimagecmd () {
	# Image generation code for image type ${type}
	ROOTFS_SIZE=`du -ks ${IMAGE_ROOTFS}|awk '{size = $1 * ${IMAGE_OVERHEAD_FACTOR} + ${IMAGE_ROOTFS_EXTRA_SPACE}; OFMT = "%.0f" ; print (size > ${IMAGE_ROOTFS_SIZE} ? size : ${IMAGE_ROOTFS_SIZE}) }'`
	${cmd}
	cd ${DEPLOY_DIR_IMAGE}/
	rm -f ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.${type}
	ln -s ${IMAGE_NAME}.rootfs.${type} ${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.${type}
}


XZ_COMPRESSION_LEVEL ?= "-e -9"
XZ_INTEGRITY_CHECK ?= "crc32"

IMAGE_CMD_jffs2 = "mkfs.jffs2 --root=${IMAGE_ROOTFS} --faketime --output=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.jffs2 ${EXTRA_IMAGECMD}"

IMAGE_CMD_cramfs = "mkcramfs ${IMAGE_ROOTFS} ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.cramfs ${EXTRA_IMAGECMD}"

IMAGE_CMD_ext2 = "genext2fs -b $ROOTFS_SIZE -d ${IMAGE_ROOTFS} ${EXTRA_IMAGECMD} ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ext2"
IMAGE_CMD_ext2.gz () {
	rm -rf ${DEPLOY_DIR_IMAGE}/tmp.gz && mkdir ${DEPLOY_DIR_IMAGE}/tmp.gz
	genext2fs -b $ROOTFS_SIZE -d ${IMAGE_ROOTFS} ${EXTRA_IMAGECMD} ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext2
	gzip -f -9 ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext2
	mv ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext2.gz ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ext2.gz
	rmdir ${DEPLOY_DIR_IMAGE}/tmp.gz
}

IMAGE_CMD_ext3 () {
	genext2fs -b $ROOTFS_SIZE -d ${IMAGE_ROOTFS} ${EXTRA_IMAGECMD} ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ext3
	tune2fs -j ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ext3
}
IMAGE_CMD_ext3.gz () {
	rm -rf ${DEPLOY_DIR_IMAGE}/tmp.gz && mkdir ${DEPLOY_DIR_IMAGE}/tmp.gz
	genext2fs -b $ROOTFS_SIZE -d ${IMAGE_ROOTFS} ${EXTRA_IMAGECMD} ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext3
	tune2fs -j ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext3
	gzip -f -9 ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext3
	mv ${DEPLOY_DIR_IMAGE}/tmp.gz/${IMAGE_NAME}.rootfs.ext3.gz ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ext3.gz
	rmdir ${DEPLOY_DIR_IMAGE}/tmp.gz
}

IMAGE_CMD_btrfs () {
	mkfs.btrfs -b `expr ${ROOTFS_SIZE} \* 1024` ${EXTRA_IMAGECMD} -r ${IMAGE_ROOTFS} ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.btrfs
}

IMAGE_CMD_squashfs = "mksquashfs ${IMAGE_ROOTFS} ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.squashfs ${EXTRA_IMAGECMD} -noappend"
IMAGE_CMD_squashfs-lzma = "mksquashfs-lzma ${IMAGE_ROOTFS} ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.squashfs-lzma ${EXTRA_IMAGECMD} -noappend"
IMAGE_CMD_tar = "cd ${IMAGE_ROOTFS} && tar -cvf ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.tar ."
IMAGE_CMD_tar.gz = "cd ${IMAGE_ROOTFS} && tar -zcvf ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.tar.gz ."
IMAGE_CMD_tar.bz2 = "cd ${IMAGE_ROOTFS} && tar -jcvf ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.tar.bz2 ."
IMAGE_CMD_tar.xz = "cd ${IMAGE_ROOTFS} && tar --xz -cvf ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.tar.xz ."
IMAGE_CMD_cpio = "cd ${IMAGE_ROOTFS} && (find . | cpio -o -H newc >${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.cpio)"
IMAGE_CMD_cpio.gz = "cd ${IMAGE_ROOTFS} && (find . | cpio -o -H newc | gzip -c -9 >${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.cpio.gz)"
IMAGE_CMD_cpio.xz = "type cpio >/dev/null; cd ${IMAGE_ROOTFS} && (find . | cpio -o -H newc | xz -c ${XZ_COMPRESSION_LEVEL} --check=${XZ_INTEGRITY_CHECK} > ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.cpio.xz) ${EXTRA_IMAGECMD}"
IMAGE_CMD_cpio.lzma = "type cpio >/dev/null; cd ${IMAGE_ROOTFS} && (find . | cpio -o -H newc | xz --format=lzma -c ${XZ_COMPRESSION_LEVEL} --check=${XZ_INTEGRITY_CHECK} >${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.cpio.lzma) ${EXTRA_IMAGECMD}"

IMAGE_CMD_ubi () {
	echo \[ubifs\] > ubinize.cfg 
	echo mode=ubi >> ubinize.cfg
	echo image=${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ubifs >> ubinize.cfg 
	echo vol_id=0 >> ubinize.cfg 
	echo vol_type=dynamic >> ubinize.cfg 
	echo vol_name=${UBI_VOLNAME} >> ubinize.cfg 
	echo vol_flags=autoresize >> ubinize.cfg
	mkfs.ubifs -r ${IMAGE_ROOTFS} -o ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ubifs ${MKUBIFS_ARGS} && ubinize -o ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.ubi ${UBINIZE_ARGS} ubinize.cfg
}
IMAGE_CMD_ubifs = "mkfs.ubifs -r ${IMAGE_ROOTFS} -o ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.ubifs.img ${MKUBIFS_ARGS}"

IMAGE_CMD_sdimg () {
        MD5SUM_SD="$(md5sum ${IMAGE_ROOTFS}/boot/uImage | awk '{print $1}')" 
        for sdsize in $(ls ${WORKDIR}/conf/sd/sd-master* | sed -e s:${WORKDIR}/conf/sd/sd-master-::g -e 's:.img.gz::g' | xargs echo) ; do
        echo "SD size: $sdsize"

        if true ; then
                echo "No cached SD image found, generating new one"
                zcat ${WORKDIR}/conf/sd/sd-master-$sdsize.img.gz > ${WORKDIR}/sd.img
                /sbin/fdisk -l -u ${WORKDIR}/sd.img

                # Output looks like:
                # Disk sd-master-1GiB.img: 0 MB, 0 bytes
                # 255 heads, 63 sectors/track, 0 cylinders, total 0 sectors
                # Units = sectors of 1 * 512 = 512 bytes
                # Sector size (logical/physical): 512 bytes / 512 bytes
                # I/O size (minimum/optimal): 512 bytes / 512 bytes
                # Disk identifier: 0x00000000
                # 
                #             Device Boot      Start         End      Blocks   Id  System
                # sd-master-1GiB.img1   *          63      144584       72261    c  W95 FAT32 (LBA)
                # sd-master-1GiB.img2          144585     1959929      907672+  83  Linux


                BYTES_PER_SECTOR="$(/sbin/fdisk -l -u sd.img | grep Units | awk '{print $9}')"
                VFAT_SECTOR_OFFSET="$(/sbin/fdisk -l -u sd.img | grep img1 | awk '{print $3}')"
                EXT3_SECTOR_OFFSET="$(/sbin/fdisk -l -u sd.img | grep img2 | awk '{print $2}')"

                LOOP_DEV="/dev/loop1"
                LOOP_DEV_FS="/dev/loop2"
                umount ${LOOP_DEV} || true
                umount ${LOOP_DEV_FS} || true
                /sbin/losetup -d ${LOOP_DEV} || true
                /sbin/losetup -d ${LOOP_DEV_FS} || true

                echo ""

                # VFAT
                echo "/sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${VFAT_SECTOR_OFFSET}) ${LOOP_DEV} ${WORKDIR}/sd.img"
                /sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${VFAT_SECTOR_OFFSET}) ${LOOP_DEV} ${WORKDIR}/sd.img

                # EXT3
                echo "/sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${EXT3_SECTOR_OFFSET}) ${LOOP_DEV_FS} ${WORKDIR}/sd.img"
                /sbin/losetup -v -o $(expr ${BYTES_PER_SECTOR} "*" ${EXT3_SECTOR_OFFSET}) ${LOOP_DEV_FS} ${WORKDIR}/sd.img
                echo "/sbin/mkfs.ext3 -L Narcissus-rootfs ${LOOP_DEV_FS}"
                /sbin/mkfs.ext3 -L Narcissus-rootfs ${LOOP_DEV_FS}

                echo ""

                echo "mount ${LOOP_DEV}"
                mount ${LOOP_DEV}

                echo "mount ${LOOP_DEV_FS}"
                mount ${LOOP_DEV_FS}

                # report mount status to log
                mount | grep loop

                if [ -e ${IMAGE_ROOTFS}/boot/MLO ] ; then
                	cp -v ${IMAGE_ROOTFS}/boot/MLO /mnt/narcissus/sd_image1/MLO
                fi

                echo "Remounting ${LOOP_DEV}"
                umount ${LOOP_DEV}
                mount ${LOOP_DEV}

                echo "Copying file system:"
		cp -r ${IMAGE_ROOTFS}/* /mnt/narcissus/sd_images2/ || true

		echo "Copying bootloaders into the boot partition"
                cp -v /mnt/narcissus/sd_image2/boot/u-boot-*.bin /mnt/narcissus/sd_image1/u-boot.bin || true
                cp -v /mnt/narcissus/sd_image2/boot/uImage-2.6* /mnt/narcissus/sd_image1/uImage || true
                cp -v /mnt/narcissus/sd_image2/boot/user.txt /mnt/narcissus/sd_image1/ || true
                cp -v /mnt/narcissus/sd_image2/boot/uEnv.txt /mnt/narcissus/sd_image1/ || true

                if [ ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.ubi ] ; then
                        echo "Copying UBIFS image to file system:"
                        cp ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.ubi /mnt/narcissus/sd_image2/boot/fs.ubi
                fi

                touch  /mnt/narcissus/sd_image2/narcissus-was-here
                echo "Remounting ${LOOP_DEV_FS}"
                umount ${LOOP_DEV_FS}
                mount ${LOOP_DEV_FS}

                echo "files in ext3 partition:" $(du -hs /mnt/narcissus/sd_image2/* | sed s:/mnt/narcissus/sd_image2/::g)

                echo "umount ${LOOP_DEV}"       
                umount ${LOOP_DEV}
                echo "umount ${LOOP_DEV_FS}"
                umount ${LOOP_DEV_FS}

                /sbin/losetup -d ${LOOP_DEV}
                /sbin/losetup -d ${LOOP_DEV_FS}

                gzip -c sd.img > ${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}-${MACHINE}-sd-$sdsize.img.gz
        fi
        done
}

EXTRA_IMAGECMD = ""
EXTRA_IMAGECMD_jffs2 ?= "--pad --little-endian --eraseblock=0x40000"
# Change these if you want default genext2fs behavior (i.e. create minimal inode number)
EXTRA_IMAGECMD_ext2 ?= "-i 8192"
EXTRA_IMAGECMD_ext2.gz ?= "-i 8192"
EXTRA_IMAGECMD_ext3 ?= "-i 8192"
EXTRA_IMAGECMD_ext3.gz ?= "-i 8192"
EXTRA_IMAGECMD_btrfs ?= ""

IMAGE_DEPENDS = ""
IMAGE_DEPENDS_jffs2 = "mtd-utils-native"
IMAGE_DEPENDS_cramfs = "cramfs-native"
IMAGE_DEPENDS_ext2 = "genext2fs-native"
IMAGE_DEPENDS_ext2.gz = "genext2fs-native"
IMAGE_DEPENDS_ext3 = "genext2fs-native e2fsprogs-native"
IMAGE_DEPENDS_ext3.gz = "genext2fs-native e2fsprogs-native"
IMAGE_DEPENDS_btrfs = "btrfs-tools-native"
IMAGE_DEPENDS_squashfs = "squashfs-tools-native"
IMAGE_DEPENDS_squashfs-lzma = "squashfs-lzma-tools-native"
IMAGE_DEPENDS_tar.xz = "tar-native xz-native"
IMAGE_DEPENDS_cpio.lzma = "xz-native"
IMAGE_DEPENDS_cpio.xz = "xz-native"
IMAGE_DEPENDS_ubi = "mtd-utils-native"
IMAGE_DEPENDS_ubifs = "mtd-utils-native"

# This variable is available to request which values are suitable for IMAGE_FSTYPES
IMAGE_TYPES = "jffs2 cramfs ext2 ext2.gz ext3 ext3.gz live squashfs squashfs-lzma ubi tar tar.gz tar.bz2 tar.xz cpio cpio.gz cpio.xz cpio.lzma"
