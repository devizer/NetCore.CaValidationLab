#!/usr/bin/env bash

# for ver in 7.5.0 9.4.0; do
# export IMAGE="multiarch/debian-debootstrap:armhf-wheezy"
export IMAGE="debian:8"
export IMAGE="devizervlad/raspbian:raspberry-wheezy"
export IMAGE="balenalib/raspberry-pi-debian:jessie"
export FORCE_UNAME_M=armv6l
export FORCE_GCC_CONFIGURE_ARGS="--target=arm-linux-gnueabihf --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib"
export VER=8.3.0
export USEGCC="" # 10
# export VER=$ver
export GCCURL=https://ftp.gnu.org/gnu/gcc/gcc-$VER/gcc-$VER.tar.xz
export SYSTEM_ARTIFACTSDIRECTORY=$HOME/GCC-ARTIFACTS-$VER
mkdir -p $SYSTEM_ARTIFACTSDIRECTORY

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash 
Say --Reset-Stopwatch

if [[ "$IMAGE" == *"arm"* ]] && [[ "$(uname -m)" == *"x86_64"* ]]; then
  Say "Register qemu static"
  docker run --rm --privileged multiarch/qemu-user-static:register --reset
fi

for f in build-gcc-utilities.sh build-gcc-task.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done


Say "Start container $IMAGE"
container="gcc-$VER-container-v2"
docker rm -f $container
docker run --privileged -t --rm -d --hostname $container --name $container "$IMAGE" sh -c "while true; do sleep 42; done"
for cmd in Say try-and-retry; do
    docker cp /usr/local/bin/$cmd $container:/usr/bin/$cmd
done
for f in build-gcc-utilities.sh build-gcc-task.sh; do
  docker cp /tmp/$f $container:/$f
done

if [[ -n "${FORCE_UNAME_M:-}" ]]; then
  Say "Force uname [${FORCE_UNAME_M:-}] for container"
  script=https://raw.githubusercontent.com/devizer/glist/master/Fake-uname.sh; 
  cmd="(wget --no-check-certificate -O /tmp/Fake-uname.sh $script 2>/dev/null || curl -kSL -o /tmp/Fake-uname.sh $script)"
  eval "$cmd || $cmd || $cmd" && sudo chmod +x /tmp/Fake-uname.sh 
  docker cp /tmp/Fake-uname.sh $container:/usr/bin/uname
  echo "${FORCE_UNAME_M:-}" | tee /tmp/system-uname-m
  docker cp /tmp/system-uname-m $container:/etc/system-uname-m
  docker exec $container bash -c "echo Container uname; uname -m"
fi

# armv6: export FORCE_GCC_CONFIGURE_ARGS="--target=arm-linux-gnueabihf --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib"
Say "Build"
docker exec -t -e ENABLE_LANGUAGES="c,c++" -e USEGCC="${USEGCC:-}" -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" -e GCCURL="${GCCURL}" -e FLAGS="-O2" -e FORCE_GCC_CONFIGURE_ARGS="${FORCE_GCC_CONFIGURE_ARGS:-}" $container bash -c "
    Say --Reset-Stopwatch
    echo FORCE ARGS: [\$FORCE_GCC_CONFIGURE_ARGS]
    Say \"ENABLE_LANGUAGES: \$ENABLE_LANGUAGES\"
    cd /
    source build-gcc-utilities.sh
    prepare_os
    Say 'BUILDING ...'
    bash -e build-gcc-task.sh

    Say 'Pack usr local'
    pushd /usr/local
    tar cf - . | gzip -1 > /gcc.tar.gz
    popd
    Say '/gcc.tar.gz completed'
"

Say "Grab gcc binaries"
docker cp $container:/gcc.tar.gz $SYSTEM_ARTIFACTSDIRECTORY/gcc.tar.gz
Say "Grab other artifacts from [$container:$SYSTEM_ARTIFACTSDIRECTORY]"
docker cp $container:$SYSTEM_ARTIFACTSDIRECTORY/. $SYSTEM_ARTIFACTSDIRECTORY

# done # for ver