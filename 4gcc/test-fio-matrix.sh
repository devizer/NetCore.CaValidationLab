SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

LOG_DIR="$SYSTEM_ARTIFACTSDIRECTORY/logs"
mkdir -p "$LOG_DIR"
FIO_LOG_DIR="$SYSTEM_ARTIFACTSDIRECTORY/fio-results"
mkdir -p "$FIO_LOG_DIR"
IMAGE_LIST="$SYSTEM_ARTIFACTSDIRECTORY/IMAGE-ARRAY.txt"
FIO_VER3_DISTRIBUTION_HOME="$SYSTEM_ARTIFACTSDIRECTORY/fio-ver3-distribution"
mkdir -p "$FIO_VER3_DISTRIBUTION_HOME"

function Load-Fio-Ver-3-Distribution() {
  Say "Loading fio ver 3 distribution, FIO_VER3_DISTRIBUTION_HOME=$FIO_VER3_DISTRIBUTION_HOME"
  sudo apt-get install tree aria2 rsync sshpass tree -y -qq
  mkdir -p ~/.ssh; printf "Host *\n   StrictHostKeyChecking no\n   UserKnownHostsFile=/dev/null" > ~/.ssh/config
  pushd "$FIO_VER3_DISTRIBUTION_HOME"
  # all tree heararchy needs too much time, about 8 minutes
  # time sshpass -p "$PASSWORD" rsync --progress -r "${LOGIN}@${SSH_HOST_AND_PATH}" .
  # .tar.xz archive only needs 3 seconds
  time sshpass -p "$PASSWORD" rsync --progress -r --include='*.xz' --include='*.xz.sha256' --exclude='plain/' --include='*/' --exclude='*' "${LOGIN}@${SSH_HOST_AND_PATH}" .
  tree -h > "$SYSTEM_ARTIFACTSDIRECTORY/fio-ver3-distribution-tree.txt"
  Say "Successfully Loaded fio ver 3 distribution, FIO_VER3_DISTRIBUTION_HOME=$FIO_VER3_DISTRIBUTION_HOME"
  popd
}

# 1
Load-Fio-Ver-3-Distribution


function Get-Container-Name-by-Image() {
  echo "fio-on-${1//[\/:\.]/-}"
}

function Publish-Containers-Logs() {
  local image container
  for image in $(cat "$IMAGE_LIST"); do
    container="$(Get-Container-Name-by-Image "$image")"
    Say "Dump Logs for the [$container] container from [$image] image"
    docker logs "$container" 2>&1 > "$LOG_DIR/$container" || true
  done 
}

cat <<-'START_CONTAINER_AS_DAEMON' > "/tmp/start-container-as-daemon.sh"
mkdir -p /fio
echo container: $CONTAINER; 
echo image: $IMAGE; 
echo machine: $(uname -m);
echo "hostname: $(hostname)"
echo "glibc: $(ldd --version | awk 'NR==1 {print $NF}')"
tail -f /dev/null
START_CONTAINER_AS_DAEMON

TOTAL_FAIL=0
TOTAL_IMAGES=0
function Run-4-Tests() {
  set +eu
  local i=0 image FAIL=0 job pids pid container
  pids=()
  for image in "$@"; do
    let "TOTAL_IMAGES+=1"
    let "i+=1"
    local container="$(Get-Container-Name-by-Image "$image")"
    echo "$image" >> "$IMAGE_LIST"
    # Say "Pulling #$TOTAL_IMAGES: [$image] and run [$container]"
    # docker pull "$image" & 
    (
        docker pull "$image" &&
        docker run -d --sysctl net.ipv6.conf.all.disable_ipv6=1 --privileged \
          --hostname "$container" --name "$container" \
          -e CONTAINER="$container" -e IMAGE="$image" \
          -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
          -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
          -v /tmp/start-container-as-daemon.sh:/tmp/start-container-as-daemon.sh \
          "$image" sh -c "echo sample output to STDERR >&2; sh /tmp/start-container-as-daemon.sh"
    ) &
    pid=$!
    sleep 0.3
    # Say "Pulling-B #$TOTAL_IMAGES: $image"
    # Say "Pulling-C #$TOTAL_IMAGES: $image"
    pids[${#pids[@]}]=$pid
    # Say "Pulled #$TOTAL_IMAGES: $image"
  done 
  
  for pid in "${pids[@]}"; do
      echo "wait for pid $pid"
      wait $pid || let "FAIL+=1"
  done

  let "TOTAL_FAIL+=FAIL"
  echo "Batch Errors: [$FAIL] Total Errors: [$TOTAL_FAIL]"
  set -eu
}





Run-4-Tests centos:6 centos:7 centos:8
Run-4-Tests arm32v7/debian:7 arm32v7/debian:8 arm32v7/debian:9 arm32v7/debian:10

Run-4-Tests arm32v7/debian:11 arm64v8/debian:8 arm64v8/debian:9 arm64v8/debian:10 arm64v8/debian:11

Run-4-Tests debian:7 debian:8 debian:9 debian:10 debian:11
Run-4-Tests ubuntu:22.04 ubuntu:21.10 ubuntu:20.04 ubuntu:18.04
Run-4-Tests ubuntu:16.04 ubuntu:14.10 ubuntu:12.04

Run-4-Tests fedora:24 fedora:25 fedora:26 fedora:27 fedora:28
Run-4-Tests fedora:29 fedora:30 fedora:31 fedora:32 fedora:33
Run-4-Tests fedora:34 fedora:35 fedora:36

Run-4-Tests gentoo/stage3-amd64-nomultilib gentoo/stage3-amd64-hardened-nomultilib
Run-4-Tests amazonlinux:1 amazonlinux:2 manjarolinux/base archlinux:base
Run-4-Tests opensuse/tumbleweed opensuse/leap:15 opensuse/leap:42

Publish-Containers-Logs

function Run-Fio-Tests() {
  local image container engine
  for image in $(cat "$IMAGE_LIST"); do
    container="$(Get-Container-Name-by-Image "$image")"
    local container_machine="$(docker exec -t "$container" uname -m)"
    container_machine="${container_machine//[\t\r\n ]/}"
    local filter="$container_machine"
    [[ "$filter" == "armv7"* ]] && filter=armv7
    Say "TEST $image, filter is [$filter]"
    Get-Sub-Directories-As-Names-Only "$FIO_VER3_DISTRIBUTION_HOME" | grep "$filter" | while IFS='' read dir_name; do
      echo " --> TRY [$dir_name]"
      mkdir -p /tmp/push-fio-to-container
      rm -rf /tmp/push-fio-to-container/*
      tar xvJf "$FIO_VER3_DISTRIBUTION_HOME/$dir_name/fio.tar.xz" -C /tmp/push-fio-to-container
      docker cp /tmp/push-fio-to-container/. "$container":/fio
      for engine in sync libaio posixaio; do
        local benchmark_log_file="$FIO_LOG_DIR/${container}-${engine} ${dir_name}.txt"
        docker exec -t "$container" sh -c 'export LD_LIBRARY_PATH=/fio; /fio/fio --name=test --randrepeat=1 --ioengine='$engine' --gtod_reduce=1 --filename=$HOME/fio-test.tmp --bs=4k --size=32K --readwrite=read 2>&1' |& tee "$benchmark_log_file"
      done
    done
  done 
}

Run-Fio-Tests
