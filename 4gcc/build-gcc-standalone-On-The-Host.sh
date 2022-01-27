#!/usr/bin/env bash

set -eu
script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash >/dev/null
Say --Reset-Stopwatch

# for ver in 7.5.0 9.4.0; do
# export IMAGE="multiarch/debian-debootstrap:armhf-wheezy"
export DEPLOY_DIR="/transient-builds/gcc-deploy"; 
mkdir -p $DEPLOY_DIR

for ver in 8.5.0 9.4.0 10.3.0 7.5.0 6.5.0 5.5.0 10.2.0; do
  export VER=$ver
  export GCCURL=https://ftp.gnu.org/gnu/gcc/gcc-$VER/gcc-$VER.tar.gz
  export SYSTEM_ARTIFACTSDIRECTORY=$HOME/GCC-ARTIFACTS-$VER
  mkdir -p $SYSTEM_ARTIFACTSDIRECTORY

  for f in build-gcc-utilities.sh build-gcc-task.sh Repack-GCC.sh; do
    try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
  done

  Say "Build $VER"
  export ENABLE_LANGUAGES="c,c++" FLAGS="-O2"

    Say "ENABLE_LANGUAGES: $ENABLE_LANGUAGES"
    source /tmp/build-gcc-utilities.sh
    # prepare_os
    bash -e /tmp/build-gcc-task.sh

    tmparch="/tmp/gcc-armv7-linux-$VER.tar.gz"
    Say "Pack /usr/local to $tmparch"
    pushd /usr/local
    tar cf - . | gzip -9 > $tmparch
    popd
    Say "Completed $tmparch. Ready to Repack"

    Say "Repacking ..."
    bash -e /tmp/Repack-GCC.sh 

    Say "Uninstalling ..."
    tmp1=/tmp/gcc-tmp; mkdir -p $tmp1; rm -rf $tmp1/*
    artifact="$DEPLOY_DIR/$(basename $tmparch)"
    tar xzf $artifact -C $tmp1
    cp $tmp1/uninstall-this-gcc.sh /usr/local/uninstall-this-gcc.sh
    rm -rf $tmp1/*
    /usr/local/uninstall-this-gcc.sh

done
