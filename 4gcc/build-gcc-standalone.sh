#!/usr/bin/env bash

export GCCURL=https://ftp.gnu.org/gnu/gcc/gcc-10.3.0/gcc-10.3.0.tar.gz
export SYSTEM_ARTIFACTSDIRECTORY=$HOME/GCC-ARTIFACTS-10.3.0
mkdir -p $SYSTEM_ARTIFACTSDIRECTORY
export IMAGE=debian:9

script=https://raw.githubusercontent.com/devizer/test-and-build/master/install-build-tools-bundle.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash 
Say --Reset-Stopwatch

for f in build-gcc-utilities.sh build-gcc-task.sh; do
  try-and-retry curl -kSL -o /tmp/$f https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/4gcc/$f
done


Say "Start container $IMAGE"
docker run --privileged -t --rm -d --hostname gcc-container --name gcc-container "$IMAGE" sh -c "while true; do sleep 42; done"
for cmd in Say try-and-retry; do
    docker cp /usr/local/bin/$cmd gcc-container:/usr/bin/$cmd
done
for f in build-gcc-utilities.sh build-gcc-task.sh; do
  docker cp /tmp/$f gcc-container:/$f
done

Say "Build"
docker exec -t -e USEGCC="${USEGCC:-}" -e SYSTEM_ARTIFACTSDIRECTORY="$SYSTEM_ARTIFACTSDIRECTORY" -e GCCURL="${GCCURL}" -e FLAGS="-O2" gcc-container bash -c "
    Say --Reset-Stopwatch
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
docker cp gcc-container:/gcc.tar.gz $SYSTEM_ARTIFACTSDIRECTORY/gcc.tar.gz
