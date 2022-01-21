#!/usr/bin/env bash

export VER=5.5.0
export GCCURL=https://ftp.gnu.org/gnu/gcc/gcc-$VER/gcc-$VER.tar.gz
export SYSTEM_ARTIFACTSDIRECTORY=$HOME/GCC-ARTIFACTS-$VER
mkdir -p $SYSTEM_ARTIFACTSDIRECTORY
export IMAGE=debian:7

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash 
Say --Reset-Stopwatch

for f in build-gcc-utilities.sh build-gcc-task.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done


Say "Start container $IMAGE"
container="gcc-$VER-container"
docker rm -f $container
docker run --privileged -t --rm -d --hostname $container --name $container "$IMAGE" sh -c "while true; do sleep 42; done"
for cmd in Say try-and-retry; do
    docker cp /usr/local/bin/$cmd $container:/usr/bin/$cmd
done
for f in build-gcc-utilities.sh build-gcc-task.sh; do
  docker cp /tmp/$f $container:/$f
done

Say "Build"
docker exec -t -e ENABLE_LANGUAGES="c,c++" -e USEGCC="${USEGCC:-}" -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" -e GCCURL="${GCCURL}" -e FLAGS="-O2" $container bash -c "
    Say --Reset-Stopwatch
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
