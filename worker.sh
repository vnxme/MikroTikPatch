#!/bin/bash

# Display the host information
  echo "HOST: $(uname -a)"

# Define the temporary working directory
  TWD='temp'
  mkdir -p $TWD
  cd ./$TWD
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
  wget -nv -O ./original_CHANGELOG https://$MIKRO_UPGRADE_URL/routeros/$TARGET_VERSION/CHANGELOG
  if [[ ! -f ./original_CHANGELOG ]]; then
    echo "ERROR: failed to fetch a changelog"
    exit 1
  else
    cat ./original_CHANGELOG && echo -e "\n"
  fi
