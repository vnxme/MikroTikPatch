#!/bin/bash

# Display the host information
  echo "HOST: $(uname -a)"

# Define temporary working directories
  TWD='./temp'
  OWD="$TWD/original"
  MWD="$TWD/modified"
  mkdir -p $OWD $MWD
  echo "PWD: $(pwd)"
  echo "OWD: $(realpath $OWD)"
  echo "MWD: $(realpath $MWD)"

# Process the time zone
  if [[ -z "$TZ" ]]; then export TZ='UTC'; fi
  echo "TZ: $TZ"

# Define the build time
  export BUILD_TIME=$(date +'%s')
  echo "BUILD_TIME: $(date -d @$BUILD_TIME +'%Y-%m-%d %H:%M:%S')"

# Process the target arch, channel and version
  if [[ -z "$TARGET_ARCH" ]]; then
    echo 'ERROR: TARGET_ARCH is empty'
    exit 1
  else
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      TARGET_ARCH_SUFFIX=''
    else
      echo 'test'
      TARGET_ARCH_SUFFIX="-$TARGET_ARCH"
    fi
    echo "TARGET_ARCH: $TARGET_ARCH ('$TARGET_ARCH_SUFFIX')"
  fi
  if [[ -z "$TARGET_CHANNEL" ]]; then
    echo 'ERROR: TARGET_CHANNEL is empty'
    exit 1
  else
    echo "TARGET_CHANNEL: $TARGET_CHANNEL"
  fi
  if [[ -z "$TARGET_VERSION" ]]; then
    LATEST_VERSION=$(wget -nv -O - https://$MIKRO_UPGRADE_URL/routeros/NEWESTa7.$TARGET_CHANNEL | cut -d ' ' -f1)
    if [[ -z "$LATEST_VERSION" ]]; then
      echo 'ERROR: both TARGET_VERSION and LATEST_VERSION are empty'
      exit 1
    else
      TARGET_VERSION=$LATEST_VERSION
    fi
  fi
  echo "TARGET_VERSION: $TARGET_VERSION"

# Obtain a changelog
  if [[ ! -f $OWD/CHANGELOG ]]; then
    wget -nv -O $OWD/CHANGELOG https://$MIKRO_UPGRADE_URL/routeros/$TARGET_VERSION/CHANGELOG
  fi
  if [[ ! -f $OWD/CHANGELOG ]]; then
    echo "ERROR: failed to fetch a changelog"
    exit 1
  else
    echo "DEBUG: obtained a changelog, saved as $OWD/CHANGELOG"
    cat $OWD/CHANGELOG && echo -e "\n"
  fi

# Create squashfs for the option package (applicable to x86 and arm64 only)
  if [[ "$TARGET_ARCH" == 'x86' ]] || [[ "$TARGET_ARCH" == 'arm64' ]]; then
    mkdir -p $MWD/packages/option/bin/
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      if [[ ! -f ./busybox/busybox_x86 ]] || [[ ! -f ./keygen/keygen_x86 ]]; then
        echo 'ERROR: failed to find busybox and/or keygen binaries'
        exit 1
      fi
      cp ./busybox/busybox_x86 $MWD/packages/option/bin/busybox
      chmod +x $MWD/packages/option/bin/busybox
      cp ./keygen/keygen_x86 $MWD/packages/option/bin/keygen
      chmod +x $MWD/packages/option/bin/keygen
    elif [[ "$TARGET_ARCH" == 'arm64' ]]; then
      if [[ ! -f ./busybox/busybox_aarch64 ]] || [[ ! -f ./keygen/keygen_aarch64 ]]; then
        echo 'ERROR: failed to find busybox and/or keygen binaries'
        exit 1
      fi
      cp ./busybox/busybox_aarch64 $MWD/packages/option/bin/busybox
      chmod +x $MWD/packages/option/bin/busybox
      cp ./keygen/keygen_aarch64 $MWD/packages/option/bin/keygen
      chmod +x $MWD/packages/option/bin/keygen
    fi
    chmod +x ./busybox/busybox_x86
    COMMANDS=$(./busybox/busybox_x86 --list)
    for cmd in $COMMANDS; do
      ln -sf /pckg/option/bin/busybox $MWD/packages/option/bin/$cmd
    done
    mksquashfs $MWD/packages/option $MWD/packages/option.sfs -quiet -comp xz -no-xattrs -b 256k
    echo "DEBUG: created squashfs of the option package, saved as $MWD/packages/option.sfs"
    # rf -rf $MWD/packages/option
  fi

# Create squashfs for the python3 package (applicable to x86 and arm64 only)
  if [[ "$TARGET_ARCH" == 'x86' ]] || [[ "$TARGET_ARCH" == 'arm64' ]]; then
    mkdir -p $MWD/packages/python3
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      if [[ ! -f $OWD/cpython3.tar.gz ]]; then
        wget -O $OWD/cpython3.tar.gz -nv https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-x86_64-unknown-linux-musl-install_only_stripped.tar.gz
      fi
    elif [[ "$TARGET_ARCH" == 'arm64' ]]; then
      if [[ ! -f $OWD/cpython3.tar.gz ]]; then
        wget -O $OWD/cpython3.tar.gz -nv https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz
      fi
    fi
    if [[ ! -f $OWD/cpython3.tar.gz ]]; then
      echo 'ERROR: failed to fetch cpython binaries'
      exit 1
    fi
    tar -xf $OWD/cpython3.tar.gz -C $MWD/packages/python3 --strip-components=1
    rm $OWD/cpython3.tar.gz
    rm -rf $MWD/packages/python3/include
    rm -rf $MWD/packages/python3/share
    mksquashfs $MWD/packages/python3 $MWD/packages/python3.sfs -quiet -comp xz -no-xattrs -b 256k
    echo "DEBUG: created squashfs of the python3 package, saved as $MWD/packages/python3.sfs"
    # rm -rf $MWD/packages/python
  fi

# Create squashfs for the caddy package (applicable to x86 and arm64 only)
  if [[ "$TARGET_ARCH" == 'x86' ]] || [[ "$TARGET_ARCH" == 'arm64' ]]; then
    mkdir -p $MWD/packages/caddy/{bin,nova/bin}
    ln -sf /rw/disk/etc/caddy $MWD/packages/caddy/etc
    cp test $MWD/packages/caddy/nova/bin/test
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      if [[ ! -f $OWD/caddy.tar.gz ]]; then
        wget -O $OWD/caddy.tar.gz -nv https://github.com/caddyserver/caddy/releases/download/v2.8.4/caddy_2.8.4_linux_amd64.tar.gz
      fi
    elif [[ "$TARGET_ARCH" == 'arm64' ]]; then
      if [[ ! -f $OWD/caddy.tar.gz ]]; then
        wget -O $OWD/caddy.tar.gz -nv https://github.com/caddyserver/caddy/releases/download/v2.8.4/caddy_2.8.4_linux_arm64.tar.gz
      fi
    fi
    if [[ ! -f $OWD/caddy.tar.gz ]]; then
      echo 'ERROR: failed to fetch caddy binary'
      exit 1
    fi
    tar -xf $OWD/caddy.tar.gz -C $MWD/packages/caddy/bin
    rm $OWD/caddy.tar.gz
    rm -rf $MWD/packages/caddy/bin/LICENSE
    rm -rf $MWD/packages/caddy/bin/README.md
    mksquashfs $MWD/packages/caddy $MWD/packages/caddy.sfs -quiet -comp xz -no-xattrs -b 256k
    echo "DEBUG: created squashfs of the caddy package, saved as $MWD/packages/caddy.sfs"
    # rm -rf $MWD/packages/caddy
  fi

# Create squashfs for the swgp-go package (applicable to x86 and arm64 only)
  if [[ "$TARGET_ARCH" == 'x86' ]] || [[ "$TARGET_ARCH" == 'arm64' ]]; then
    mkdir -p $MWD/packages/swgp-go/bin
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      if [[ ! -f $OWD/swgp-go.tar.zst ]]; then
        wget -O $OWD/swgp-go.tar.zst -nv https://github.com/database64128/swgp-go/releases/download/v1.6.0/swgp-go-v1.6.0-linux-x86-64-v2.tar.zst
      fi
    elif [[ "$TARGET_ARCH" == 'arm64' ]]; then
      if [[ ! -f $OWD/swgp-go.tar.zst ]]; then
        wget -O $OWD/swgp-go.tar.zst -nv https://github.com/database64128/swgp-go/releases/download/v1.6.0/swgp-go-v1.6.0-linux-arm64.tar.zst
      fi
    fi
    if [[ ! -f $OWD/swgp-go.tar.zst ]]; then
      echo 'ERROR: failed to fetch caddy binary'
      exit 1
    fi
    tar --zstd -xf $OWD/swgp-go.tar.zst -C $MWD/packages/swgp-go/bin
    rm $OWD/swgp-go.tar.zst
    mksquashfs $MWD/packages/swgp-go $MWD/packages/swgp-go.sfs -quiet -comp xz -no-xattrs -b 256k
    echo "DEBUG: created squashfs of the swgp-go package, saved as $MWD/packages/swgp-go.sfs"
    # rm -rf $MWD/packages/swgp-go
  fi

# Create an ISO (patch the kernel and the root package, re-sign the remaining original packages, create the custom packages)
  if [[ "$TARGET_ARCH" == 'x86' ]] || [[ "$TARGET_ARCH" == 'arm64' ]]; then
    if [[ ! -f $OWD/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso ]];  then
      wget -nv -O $OWD/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso https://download.mikrotik.com/routeros/$TARGET_VERSION/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso
    fi
    if [[ ! -f $OWD/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso ]];  then
      echo 'ERROR: failed to fetch an optical disc image'
      exit 1
    fi
    mkdir $OWD/iso $MWD/iso
    mount -o loop,ro $OWD/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso $OWD/iso
    cp -r $OWD/iso/* $MWD/iso/
    rsync -a $OWD/iso/ $MWD/iso/
    umount $OWD/iso
    rm -rf $OWD/iso
    mkdir $OWD/packages
    mv $MWD/iso/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $OWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk
    cp $OWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk
    python3 patch.py npk $MWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk
    NPK_FILES=$(find $MWD/iso/*.npk)
    for file in $NPK_FILES; do
      cp $file $OWD/packages/$(basename $file)
      python3 npk.py sign $file $file
      cp $file $MWD/packages/$(basename $file)
    done
    cp $MWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/iso/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk
    SFS_FILES=$(find $MWD/packages/*.sfs)
    for file in $SFS_FILES; do
      name=$(basename $file .sfs)
      python3 npk.py create $MWD/iso/gps-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/iso/$name-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $name $file -desc="$name"
      cp $MWD/iso/$name-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/packages/$name-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk
    done
    mkdir $MWD/efiboot
    mount -o loop $MWD/iso/efiboot.img $MWD/efiboot
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      cp $MWD/efiboot/linux.x86_64 $OWD/BOOTX64.EFI
      python3 patch.py kernel $MWD/efiboot/linux.x86_64
      mkdir $OWD/initramfs_iso; cp kernel.initramfs.bin $OWD/iso.initramfs.bin; cd $OWD/initramfs_iso; cpio -i < ../iso.initramfs.bin; zip -r -y ../initramfs_iso-$TARGET_ARCH-$TARGET_VERSION.zip *; cd -; rm kernel.*.*
      cp $MWD/efiboot/linux.x86_64 $MWD/BOOTX64.EFI
      cp $MWD/BOOTX64.EFI $MWD/iso/isolinux/linux
      umount $MWD/efiboot
      mkisofs -o $MWD/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso \
                  -V "MikroTik $TARGET_VERSION $TARGET_ARCH" \
                  -sysid "" -preparer "MiKroTiK" \
                  -publisher "" -A "MiKroTiK RouterOS" \
                  -input-charset utf-8 \
                  -b isolinux/isolinux.bin \
                  -c isolinux/boot.cat \
                  -no-emul-boot \
                  -boot-load-size 4 \
                  -boot-info-table \
                  -eltorito-alt-boot \
                  -e efiboot.img \
                  -no-emul-boot \
                  -R -J \
                  $MWD/iso
    elif [[ "$TARGET_ARCH" == 'arm64' ]]; then
      cp $MWD/efiboot/EFI/BOOT/BOOTAA64.EFI $OWD/BOOTAA64.EFI
      python3 patch.py kernel $MWD/efiboot/EFI/BOOT/BOOTAA64.EFI
      mkdir $OWD/initrd_iso; cp kernel.initrd.bin $OWD/iso.initrd.bin; cd $OWD/initrd_iso; cpio -i < ../iso.initrd.bin; zip -r -y ../initrd_iso-$TARGET_ARCH-$TARGET_VERSION.zip *; cd -; rm kernel.*.*
      cp $MWD/efiboot/EFI/BOOT/BOOTAA64.EFI $MWD/BOOTAA64.EFI
      umount $MWD/efiboot
      xorriso -as mkisofs -o $MWD/mikrotik-$TARGET_VERSION$TARGET_ARCH_SUFFIX.iso \
                  -V "MikroTik $TARGET_VERSION $TARGET_ARCH" \
                  -sysid "" -preparer "MiKroTiK" \
                  -publisher "" -A "MiKroTiK RouterOS" \
                  -input-charset utf-8 \
                  -b efiboot.img \
                  -no-emul-boot \
                  -R -J \
                  $MWD/iso
    fi
    rm -rf $MWD/efiboot
    rm -rf $MWD/iso
    NPK_FILES=$(find $OWD/packages/*.npk)
    for file in $NPK_FILES; do
      python3 patch.py files $file $OWD/packages
      python3 patch.py squashfs $file $OWD/packages
    done
    cd $OWD/packages; zip -r -y ../unpacked_files-$TARGET_ARCH-$TARGET_VERSION.zip * -x *.npk *.sfs; cd -
    cd $MWD/packages; zip ../all_packages-$TARGET_ARCH-$TARGET_VERSION.zip *.npk; cd -
  fi

# Create a CHR raw disk image
  if [[ "$TARGET_ARCH" == 'x86' ]] || [[ "$TARGET_ARCH" == 'arm64' ]]; then
    if [[ ! -f $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img ]]; then
      wget -nv -O $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img.zip https://download.mikrotik.com/routeros/$TARGET_VERSION/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img.zip
      if [[ -f $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img.zip ]]; then
        unzip $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img.zip -d $OWD
        rm $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img.zip
      fi
    fi
    if [[ ! -f $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img ]]; then
      echo 'ERROR: failed to fetch a CHR raw disk image'
      exit 1
    fi
    truncate --size 128M $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img
    sgdisk --clear --set-alignment=2 \
        --new=1::+32M --typecode=1:8300 --change-name=1:"RouterOS Boot" --attributes=1:set:2 \
        --new=2::-0 --typecode=2:8300 --change-name=2:"RouterOS" \
        --gpttombr=1:2 \
        $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img
    dd if=$MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img of=$MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.pt.bin bs=1 count=66 skip=446
    echo -e "\x80" | dd of=$MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.pt.bin bs=1 count=1 conv=notrunc
    sgdisk --mbrtogpt --clear --set-alignment=2 \
        --new=1::+32M --typecode=1:8300 --change-name=1:"RouterOS Boot" --attributes=1:set:2 \
        --new=2::-0 --typecode=2:8300 --change-name=2:"RouterOS" \
        $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img
    dd if=mbr.bin of=$MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img bs=1 count=446 conv=notrunc
    dd if=$MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.pt.bin of=$MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img bs=1 count=66 seek=446 conv=notrunc
    qemu-nbd -c /dev/nbd0 -f raw $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img
    mkfs.vfat -n "Boot" /dev/nbd0p1
    mkfs.ext4 -F -L "RouterOS" -m 0 /dev/nbd0p2
    mkdir -p $OWD/img/{boot,routeros} $MWD/img/{boot,routeros}
    mount /dev/nbd0p1 $MWD/img/boot/
    if [[ "$TARGET_ARCH" == 'x86' ]]; then
      # mkdir -p $MWD/img/boot/{BOOT,EFI/BOOT}
      # cp $MWD/BOOTX64.EFI $MWD/img/boot/EFI/BOOT/BOOTX64.EFI
      # extlinux --install  -H 64 -S 32 $MWD/img/boot/BOOT
      # echo -e "default system\nlabel system\n\tkernel /EFI/BOOT/BOOTX64.EFI\n\tappend load_ramdisk=1 root=/dev/ram0 quiet" > $MWD/img/boot/BOOT/syslinux.cfg

      cp $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img
      qemu-nbd -c /dev/nbd1 -f raw $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img
      python3 patch.py block /dev/nbd1p1 EFI/BOOT/BOOTX64.EFI
      mkdir $OWD/initramfs_chr; cp kernel.initramfs.bin $OWD/chr.initramfs.bin; cd $OWD/initramfs_chr; cpio -i < ../chr.initramfs.bin; zip -r -y ../initramfs_chr-$TARGET_ARCH-$TARGET_VERSION.zip *; cd -; rm kernel.*.*
      mkdir -p $MWD/img/{bios-boot,bios-routeros}
      mount /dev/nbd1p1 $MWD/img/bios-boot/
      cp $MWD/img/bios-boot/EFI/BOOT/BOOTX64.EFI $MWD/CHR.BOOTX64.EFI
      umount /dev/nbd1p1
      shred -v -n 1 -z /dev/nbd1p2
      mkfs.ext4 -F -L "RouterOS"  -m 0 /dev/nbd1p2
      mount /dev/nbd1p2 $MWD/img/bios-routeros/
      mkdir -p $MWD/img/bios-routeros/{var/pdb/{system,option},boot,rw}
      cp $MWD/packages/option-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/img/bios-routeros/var/pdb/option/image
      cp $MWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/img/bios-routeros/var/pdb/system/image
      umount /dev/nbd1p2
      qemu-nbd -d /dev/nbd1

      mkdir -p $MWD/img/boot/EFI/BOOT
      cp $MWD/CHR.BOOTX64.EFI $MWD/img/boot/EFI/BOOT/BOOTX64.EFI
    elif [[ "$TARGET_ARCH" == 'arm64' ]]; then
      qemu-nbd -c /dev/nbd1 -f raw $OWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX.img
      mkdir -p $OWD/img/boot
      mount /dev/nbd1p1 $OWD/img/boot/
      python3 patch.py kernel $OWD/img/boot/EFI/BOOT/BOOTAA64.EFI -O $MWD/CHR.BOOTAA64.EFI
      mkdir $OWD/initrd_chr; cp kernel.initrd.bin $OWD/chr.initrd.bin; cd $OWD/initrd_chr; cpio -i < ../chr.initrd.bin; zip -r -y ../initrd_chr-$TARGET_ARCH-$TARGET_VERSION.zip *; cd -; rm kernel.*.*
      mkdir -p  $MWD/img/boot/EFI/BOOT
      cp $MWD/CHR.BOOTAA64.EFI $MWD/img/boot/EFI/BOOT/BOOTAA64.EFI
      umount /dev/nbd1p1
      qemu-nbd -d /dev/nbd1
    fi
    umount /dev/nbd0p1
    mount  /dev/nbd0p2 $MWD/img/routeros/
    mkdir -p $MWD/img/routeros/{var/pdb/{system,option},boot,rw}
    cp $MWD/packages/option-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/img/routeros/var/pdb/option/image
    cp $MWD/packages/routeros-$TARGET_VERSION$TARGET_ARCH_SUFFIX.npk $MWD/img/routeros/var/pdb/system/image
    umount /dev/nbd0p2
    qemu-nbd -d /dev/nbd0
    rm -rf $OWD/img $MWD/img

    qemu-img convert -f raw -O qcow2 $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.qcow2
    qemu-img convert -f raw -O vmdk $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vmdk
    qemu-img convert -f raw -O vpc $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhd
    qemu-img convert -f raw -O vhdx $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhdx
    qemu-img convert -f raw -O vdi $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vdi

    cd $MWD
    zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.qcow2.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.qcow2
    zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vmdk.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vmdk
    zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhd.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhd
    zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhdx.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhdx
    zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vdi.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vdi
    zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img
    cd -

    rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.qcow2
    rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vmdk
    rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhd
    rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vhdx
    rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.vdi
    rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-uefi.img

    if [[ -f $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img ]]; then
      qemu-img convert -f raw -O qcow2 $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.qcow2
      qemu-img convert -f raw -O vmdk $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vmdk
      qemu-img convert -f raw -O vpc $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhd
      qemu-img convert -f raw -O vhdx $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhdx
      qemu-img convert -f raw -O vdi $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vdi

      cd $MWD
      zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.qcow2.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.qcow2
      zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vmdk.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vmdk
      zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhd.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhd
      zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhdx.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhdx
      zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vdi.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vdi
      zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img.zip chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img
      cd -

      rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.qcow2
      rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vmdk
      rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhd
      rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vhdx
      rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.vdi
      rm $MWD/chr-$TARGET_VERSION$TARGET_ARCH_SUFFIX-bios.img
    fi
  fi
