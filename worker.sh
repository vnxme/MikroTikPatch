#!/bin/bash

# Display the host information
  echo "HOST: $(uname -a)"

# Define the temporary working directory
  TWD='temp'
  mkdir -p $TWD
  echo "PWD: $(pwd)"

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
    if [[ "$TARGET_ARCH"=='x86' ]]; then
      TARGET_ARCH_SUFFIX=''
    else
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
  wget -nv -O ./$TWD/original_CHANGELOG https://$MIKRO_UPGRADE_URL/routeros/$TARGET_VERSION/CHANGELOG
  if [[ ! -f ./$TWD/original_CHANGELOG ]]; then
    echo "ERROR: failed to fetch a changelog"
    exit 1
  else
    cat ./$TWD/original_CHANGELOG && echo -e "\n"
  fi

# Create squashfs for the option package (applicable to x86 and arm64 only)
  mkdir -p ./$TWD/patched_option/bin/
  if [[ "$TARGET_ARCH"=='x86' ]]; then
    cp ./busybox/busybox_x86 ./$TWD/patched_option/bin/busybox
    chmod +x ./$TWD/patched_option/bin/busybox
    cp ./keygen/keygen_x86 ./$TWD/patched_option/bin/keygen
    chmod +x ./$TWD/patched_option/bin/keygen
  elif [[ "$TARGET_ARCH"=='arm64' ]]; then
    cp ./busybox/busybox_aarch64 ./$TWD/patched_option/bin/busybox
    chmod +x ./$TWD/patched_option/bin/busybox
    cp ./keygen/keygen_aarch64 ./$TWD/patched_option/bin/keygen
    chmod +x ./$TWD/patched_option/bin/keygen
  fi
  chmod +x ./busybox/busybox_x86
  COMMANDS=$(./busybox/busybox_x86 --list)
  for cmd in $COMMANDS; do
    ln -sf /pckg/option/bin/busybox ./$TWD/patched_option/bin/$cmd
  done
  mksquashfs ./$TWD/patched_option ./$TWD/patched_option.sfs -quiet -comp xz -no-xattrs -b 256k
  # rf -rf ./$TWD/patched_option

# Create squashfs for the python3 package (applicable to x86 and arm64 only)
  mkdir -p ./$TWD/patched_python3
  if [[ "$TARGET_ARCH"=='x86' ]]; then
    wget -O ./$TWD/patched_cpython3.tar.gz -nv https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-x86_64-unknown-linux-musl-install_only_stripped.tar.gz
  elif [[ "$TARGET_ARCH"=='arm64' ]]; then
    wget -O ./$TWD/patched_cpython3.tar.gz -nv https://github.com/indygreg/python-build-standalone/releases/download/20241016/cpython-3.11.10+20241016-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz
  fi
  if [[ ! -f ./$TWD/patched_cpython3.tar.gz ]]; then
    echo 'ERROR: failed to fetch CPython'
    exit 1
  fi
  tar -xf ./$TWD/patched_cpython3.tar.gz -C ./$TWD/patched_python3 --strip-components=1
  rm ./$TWD/patched_cpython3.tar.gz
  rm -rf ./$TWD/patched_python3/include
  rm -rf ./$TWD/patched_python3/share
  mksquashfs ./$TWD/patched_python3 ./$TWD/patched_python3.sfs -quiet -comp xz -no-xattrs -b 256k
  # rm -rf ./$TWD/patched_python
