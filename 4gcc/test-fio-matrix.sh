SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-/transient-builds}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

CONTAINERS_BOOT_LOG_DIR="$SYSTEM_ARTIFACTSDIRECTORY/containers-boot-logs"
mkdir -p "$CONTAINERS_BOOT_LOG_DIR"
FIO_LOG_DIR="$SYSTEM_ARTIFACTSDIRECTORY/structured-fio-benchmark-results"
mkdir -p "$FIO_LOG_DIR"
IMAGE_LIST="$SYSTEM_ARTIFACTSDIRECTORY/IMAGE-ARRAY.txt"
FIO_VER3_DISTRIBUTION_HOME="$SYSTEM_ARTIFACTSDIRECTORY/fio-ver3-distribution"
mkdir -p "$FIO_VER3_DISTRIBUTION_HOME"

SOURCE_UTILITIES="$(pwd)/build-gcc-utilities.sh"
Say "SOURCE_UTILITIES: [$SOURCE_UTILITIES]"
ls -la "$SOURCE_UTILITIES"

function Load-Fio-Ver-3-Distribution() {
  Say "Loading fio ver 3 distribution, FIO_VER3_DISTRIBUTION_HOME=$FIO_VER3_DISTRIBUTION_HOME"
  sudo apt-get install tree aria2 rsync sshpass tree p7zip-full -y -qq
  mkdir -p ~/.ssh; printf "Host *\n   StrictHostKeyChecking no\n   UserKnownHostsFile=/dev/null" > ~/.ssh/config
  pushd "$FIO_VER3_DISTRIBUTION_HOME"
  # all tree heararchy needs too much time, about 8 minutes
  # time sshpass -p "$PASSWORD" rsync --progress -r "${LOGIN}@${SSH_HOST_AND_PATH}" .
  # .tar.xz archive only needs 3 seconds
  # MUTED: --progress
  time sshpass -p "$PASSWORD" rsync -r --include='*.xz' --include='*.xz.sha256' --exclude='plain/' --include='*/' --exclude='*' "${LOGIN}@${SSH_HOST_AND_PATH}" .
  tree -h > "$SYSTEM_ARTIFACTSDIRECTORY/fio-ver3-distribution-tree.txt"
  popd
  Say "Successfully Loaded fio ver 3 distribution, FIO_VER3_DISTRIBUTION_HOME=$FIO_VER3_DISTRIBUTION_HOME"

  Say "Convert ver2 to ver-3"
  work=$HOME/fio-ver-2-to-3
  mkdir -p "$work"; 
  pushd $work
  sshpass -p "$PASSWORD" rsync -r --include="*.xz" --exclude="*" --progress "${LOGIN}@frs.sourceforge.net:/home/frs/p/fio/ver2/" .
  for xz in *.xz; do
    filename="${xz%.*}"
    to="$FIO_VER3_DISTRIBUTION_HOME/$filename"
    mkdir -p "$to"
    echo "[$xz] --> [$to/fio.xz]"
    # cat "$xz" | xz -d > "$to/fio.xz"
    cp -f "$xz" "$to/fio.xz"
  done
  popd
  Say "Complete conversion ver2 to ver-3"

}

# 1
Load-Fio-Ver-3-Distribution


function Get-Container-Name-by-Image() {
  echo "fio-on-${1//[\/:\.]/-}"
}

function Publish-Containers-Logs() {
  local image container
  cat "$IMAGE_LIST" | while IFS=' ' read image container; do
  # for image in $(cat "$IMAGE_LIST"); do
    # container="$(Get-Container-Name-by-Image "$image")"
    Say "Dump Logs for the [$container] container from [$image] image"
    docker logs "$container" 2>&1 > "$CONTAINERS_BOOT_LOG_DIR/$container" || true
  done 
}

cat <<-'START_CONTAINER_AS_DAEMON' > "/tmp/start-container-as-daemon.sh"
mkdir -p /fio
echo "host.container: $CONTAINER"; 
echo "host.image: $IMAGE";
echo "host.os: $(get_linux_os_id)";
echo "host.machine: $(uname -m)";
echo "host.hostname: $(hostname || cat /etc/hostname)"
echo "host.glibc: $(ldd --version | awk 'NR==1 {print $NF}')"
tail -f /dev/null
START_CONTAINER_AS_DAEMON

TOTAL_FAIL=0
TOTAL_IMAGES=0
function Run-4-Tests() {
  set +eu
  local i=0 image FAIL=0 job pids pid container force_name;
  if [[ "${1:-}" == "--force-name" ]]; then
    # does NOT fully implemented
    force_name="${2}"
    shift; shift;
  fi

  pids=()
  for image in "$@"; do
    let "TOTAL_IMAGES+=1"
    let "i+=1"
    local container="$(Get-Container-Name-by-Image "$image")"
    if [[ -n "${force_name:-}" ]]; then container="${force_name}"; fi
    echo "$image $container" >> "$IMAGE_LIST"
    Say "Pulling #$TOTAL_IMAGES: [$container] from [$image] image"
    (
        docker pull -q "$image" &&
        docker run -d --sysctl net.ipv6.conf.all.disable_ipv6=1 --privileged \
          --hostname "$container" --name "$container" \
          -e CONTAINER="$container" -e IMAGE="$image" \
          -v "$SOURCE_UTILITIES":/build-gcc-utilities.sh \
          -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static \
          -v /usr/bin/qemu-aarch64-static:/usr/bin/qemu-aarch64-static \
          -v /tmp/start-container-as-daemon.sh:/tmp/start-container-as-daemon.sh \
          "$image" bash -c "echo sample output to STDERR >&2; source /build-gcc-utilities.sh; source /tmp/start-container-as-daemon.sh"
    ) &
    pid=$!
    sleep 0.3
    pids[${#pids[@]}]=$pid
  done 
  
  for pid in "${pids[@]}"; do
      echo "wait for pid $pid"
      wait $pid || let "FAIL+=1"
  done

  let "TOTAL_FAIL+=FAIL"
  echo "Batch Errors: [$FAIL] Total Errors: [$TOTAL_FAIL]"
  set -eu
}

function Run-Multiarch-Tests() {
  local image="$1"
  local manifest="$(Get-Docker-Image-Manifest "$image")"
  local arch;
  for arch in amd64 arm64 armv7; do
    local digest="$(cat "$manifest" | Find-Docker-Image-Digest-for-Architecture "$arch")"
    if [[ -n "$digest" ]]; then
      Say "Arch [$arch] is supported for [$image] image. Digest: [$digest]"
      Run-4-Tests --force-name "$(Get-Container-Name-by-Image "$image")-${arch}" "${image}@${digest}"
    fi
  done
}

# echo SHORT TEST; Run-4-Tests debian:11 arm32v7/fedora:28 arm32v7/fedora:35 multiarch/ubuntu-debootstrap:arm64-focal


# OpenSUSE
# ABANDONED
# theese two images are abandoned in 2018
# arm32v7/opensuse -      42.2 42.3 latest leap tumbleweed, leap & latest is 42 (2.22), tumbleweed too old (2.26)
# arm64v8/opensuse - 42.1 42.2 42.3 latest leap tumbleweed

# Obsolete
# armv7 V15.3
# Run-4-Tests --force-name "fio-on-opensuse-15-3-arm32v7" "opensuse/leap@sha256:fd21070081a4909b699f77eff9ec6ce5e7bb351a87a0b66dd6d1e764ff3ffd75"
# ARMV7 tumbleweed
# Run-4-Tests --force-name "fio-on-opensuse-tumbleweed-arm32v7" "opensuse/tumbleweed@sha256:4ac6f1b552f335b1dd4faff8c5d71b2cdb753aa0561cd2068f2985d0ca97c1c2"
# armv8 v15.3
# Run-4-Tests --force-name "fio-on-opensuse-15-3-arm64v8" "opensuse/leap@sha256:db4800b5d59741a469a53bfb3e59a3867550ac2c489db770aaa611589b8f8ae6"
# ARMV8 tumbleweed
# Run-4-Tests --force-name "fio-on-opensuse-tumbleweed-arm64v8" "opensuse/tumbleweed@sha256:0a9fbfefbb1d5a37a3edc316cb6387e8848d7b1855f7a1ec1913036deea3fb84"
# Run-4-Tests opensuse/tumbleweed opensuse/leap:15 

# New Way

echo 'SKIP SHORT
Run-4-Tests arm64v8/fedora:35 arm32v7/fedora:35 fedora:35 debian:11 arm64v8/debian:11
Run-Multiarch-Tests centos:8
'

Run-Multiarch-Tests opensuse/leap:15
Run-Multiarch-Tests opensuse/tumbleweed
Run-Multiarch-Tests centos:7
Run-Multiarch-Tests centos:8

Run-4-Tests arm32v7/opensuse:42.3 arm64v8/opensuse:42.3 opensuse/leap:42

# FULL TEST
Run-4-Tests centos:6 # centos:7 centos:8 are via multiarch

# Debian
Run-4-Tests arm32v7/debian:7 arm32v7/debian:8 arm32v7/debian:9 arm32v7/debian:10

Run-4-Tests arm32v7/debian:11 arm64v8/debian:8 arm64v8/debian:9 arm64v8/debian:10 arm64v8/debian:11

Run-4-Tests debian:7 debian:8 debian:9 debian:10 debian:11

# Ubuntu
Run-4-Tests arm64v8/ubuntu:22.04 arm64v8/ubuntu:21.10 arm64v8/ubuntu:20.04 arm64v8/ubuntu:18.04
Run-4-Tests arm64v8/ubuntu:16.04 arm64v8/ubuntu:14.04

Run-4-Tests arm32v7/ubuntu:22.04 arm32v7/ubuntu:21.10 arm32v7/ubuntu:20.04 arm32v7/ubuntu:18.04
Run-4-Tests arm32v7/ubuntu:16.04 arm32v7/ubuntu:14.04

Run-4-Tests ubuntu:22.04 ubuntu:21.10 ubuntu:20.04 ubuntu:18.04
Run-4-Tests ubuntu:16.04 ubuntu:14.04 ubuntu:12.04

# Fedora
Run-4-Tests arm32v7/fedora:24 arm32v7/fedora:25 arm32v7/fedora:26 arm32v7/fedora:27 arm32v7/fedora:28
Run-4-Tests arm32v7/fedora:29 arm32v7/fedora:30 arm32v7/fedora:31 arm32v7/fedora:32 arm32v7/fedora:33
Run-4-Tests arm32v7/fedora:34 arm32v7/fedora:35 arm32v7/fedora:36

Run-4-Tests arm64v8/fedora:24 arm64v8/fedora:25 arm64v8/fedora:26 arm64v8/fedora:27 arm64v8/fedora:28
Run-4-Tests arm64v8/fedora:29 arm64v8/fedora:30 arm64v8/fedora:31 arm64v8/fedora:32 arm64v8/fedora:33
Run-4-Tests arm64v8/fedora:34 arm64v8/fedora:35 arm64v8/fedora:36

# ARMv7 since fedora:25, ARM64 since fedora:26
Run-4-Tests fedora:24 fedora:25 fedora:26 fedora:27 fedora:28
Run-4-Tests fedora:29 fedora:30 fedora:31 fedora:32 fedora:33
Run-4-Tests fedora:34 fedora:35 fedora:36

# Exotic
Run-4-Tests gentoo/stage3-amd64-nomultilib gentoo/stage3-amd64-hardened-nomultilib
Run-4-Tests amazonlinux:1 amazonlinux:2 manjarolinux/base archlinux:base


Say "Wait for 20 seconds before catch logs"
sleep 20
Publish-Containers-Logs

TRY_COUNT=0
function Run-Fio-Tests() {
  local image container engine
  # for each running image
  cat "$IMAGE_LIST" | while IFS=' ' read image container; do
  # for image in $(cat "$IMAGE_LIST"); do
    # container="$(Get-Container-Name-by-Image "$image")"
    local container_machine="$(docker exec -t "$container" uname -m)"
    container_machine="${container_machine//[$'\t\r\n ']}"
    local filter="$container_machine"
    [[ "$container_machine" == "aarch64"* ]] && filter='aarch64\|arm64'
    [[ "$container_machine" == "armv7"* ]] && filter="armv7\|armhf"
    [[ "$container_machine" == "x86_64"* ]] && filter="x86_64\|amd64"
    Say "TEST $image, filter is [$filter]"
    # for each fio of the same arch
    Get-Sub-Directories-As-Names-Only "$FIO_VER3_DISTRIBUTION_HOME" | grep "$filter" | while IFS='' read dir_name; do
      let "TRY_COUNT+=1"
      echo -e "\n --> TRY #${TRY_COUNT} [$dir_name]"
      fio_push_dir="/tmp/push-fio-to-container/$dir_name"
      if [[ ! -d "$fio_push_dir" ]]; then
        mkdir -p "$fio_push_dir"
        if [[ -e "$FIO_VER3_DISTRIBUTION_HOME/$dir_name/fio.tar.xz" ]]; then
          # ver 3
          tar xJf "$FIO_VER3_DISTRIBUTION_HOME/$dir_name/fio.tar.xz" -C "$fio_push_dir"
        else
          # ver 2
          cat "$FIO_VER3_DISTRIBUTION_HOME/$dir_name/fio.xz" | xz -d > "$fio_push_dir/fio"
          chmod +x "$fio_push_dir/fio"
        fi
      fi
      docker exec -t "$container" rm -rf "/fio/*"
      docker cp "${fio_push_dir}/." "$container":/fio
      for engine in sync libaio posixaio; do
        local         benchmark_log_file="$FIO_LOG_DIR/${container}-${engine}/${dir_name}.txt"
        local   benchmark_exit_code_file="$FIO_LOG_DIR/${container}-${engine}/${dir_name}.exit-code"
        local  benchmark_structured_file="$FIO_LOG_DIR/${container}-${engine}/${dir_name}.summary"
        mkdir -p "$(dirname "$benchmark_log_file")"
        docker exec -t "$container" sh -c 'rm -f /fio-exit-code; export LD_LIBRARY_PATH=/fio; /fio/fio --name=test --randrepeat=1 --ioengine='$engine' --gtod_reduce=1 --filename=$HOME/fio-test.tmp --bs=4k --size=32K --readwrite=read 2>&1; err=$?; echo $err >/fio-exit-code; exit 0' |& tee "$benchmark_log_file"
        docker cp "$container":/fio-exit-code "$benchmark_exit_code_file"
        echo "
benchmark.engine: $engine
benchmark.exit.code: $(cat "$benchmark_exit_code_file")
benchmark.output.size: $(stat --printf="%s" "$benchmark_log_file")
fio.raw: $dir_name
$(cat "$CONTAINERS_BOOT_LOG_DIR/$container")
" |& tee -a "$benchmark_structured_file"

      done # engine
      # break # SHORT TEST needs break here
    done # fio
    # TODO: Delete Image and Container
  done # image
}

Run-Fio-Tests

Say "Pack [${CONTAINERS_BOOT_LOG_DIR}]"
7z a -mx=1 "${CONTAINERS_BOOT_LOG_DIR}.7z" "${CONTAINERS_BOOT_LOG_DIR}" -sdel
Say "Pack [${FIO_LOG_DIR}]"
7z a -mx=1 "${FIO_LOG_DIR}.7z" "${FIO_LOG_DIR}" -sdel
Say "Pack [$FIO_VER3_DISTRIBUTION_HOME]"
7z a -mx=1 "${FIO_VER3_DISTRIBUTION_HOME} (xz only).7z" "${FIO_VER3_DISTRIBUTION_HOME}" -sdel
Say "Pack Complete. Welcomeback"
