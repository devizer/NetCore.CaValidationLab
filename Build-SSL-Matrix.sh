#!/usr/bin/env bash
set -e
set -u
set -o pipefail

NET_VERS="3.1 5.0 6.0"
NET_VERS_CENTOS_6="3.1.120"
ARGS='
fedora_prepare | fedora:36 | Fedora-36
debian_prepare | ubuntu:22.04           | Ubuntu-22.04

echo gentoo is ready already | gentoo/stage3-amd64-nomultilib | Gentoo

pacman -Syu --noconfirm haveged; pacman -Sy --noconfirm sudo tar | manjarolinux/base | Manjaro

fedora_prepare | fedora:24 | Fedora-24
fedora_prepare | fedora:25 | Fedora-25
fedora_prepare | fedora:26 | Fedora-26
fedora_prepare | fedora:27 | Fedora-27
fedora_prepare | fedora:28 | Fedora-28
fedora_prepare | fedora:29 | Fedora-29
fedora_prepare | fedora:30 | Fedora-30
fedora_prepare | fedora:31 | Fedora-31
fedora_prepare | fedora:32 | Fedora-32
fedora_prepare | fedora:33 | Fedora-33
fedora_prepare | fedora:34 | Fedora-34
fedora_prepare | fedora:35 | Fedora-35

pacman -Sy --noconfirm sudo tar | archlinux:base | Arch


prepare_centos | centos:7.0.1406        | CentOS-7
prepare_centos | centos:6.10            | CentOS-6
prepare_centos | centos:8               | CentOS-8

alpine_prepare | alpine:3.12            | Alpine-3.12
alpine_prepare | alpine:3.13            | Alpine-3.13
alpine_prepare | alpine:3.14            | Alpine-3.14
                                         
debian_prepare | debian:8               | Debian-8   
debian_prepare | debian:9               | Debian-9
debian_prepare | debian:10              | Debian-10
debian_prepare | debian:11              | Debian-11
                                         
debian_prepare | ubuntu:20.04           | Ubuntu-20.04
debian_prepare | ubuntu:21.10           | Ubuntu-21.10
debian_prepare | ubuntu:18.04           | Ubuntu-18.04
debian_prepare | ubuntu:16.04           | Ubuntu-16.04
debian_prepare | ubuntu:14.04           | Ubuntu-14.04

opensuse_prepare | opensuse/leap:42    | SUSE-42
opensuse_prepare | opensuse/leap:15    | SUSE-15
opensuse_prepare | opensuse/tumbleweed | SUSE-Tumbleweed
'


function trim() {
  # echo -e "$1" | tr -d '[:space:]'
  echo -e "${*:-}" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'
}

Say --Reset-Stopwatch

Work=/transient-builds/ssl-matrix
Say "git clone tests: [$Work/test-sources.sh]"
sudo mkdir -p $Work; sudo chown -R $(whoami) $Work
pushd $Work
test ! -d w3top-bin && git clone https://github.com/devizer/w3top-bin
cd w3top-bin
git pull
cat tests/*.sh > $Work/test-sources.sh; chmod +x $Work/test-sources.sh
popd

count=0;
function get_image_count() {
  echo "$ARGS" | while IFS='|' read script image title; do
    if [[ -n "${script:-}" ]]; then count="$((count+1))"; fi
    echo "$count, [$script]" > /dev/null
  done
  echo $count;
}
count=$(get_image_count)
Say "Count: $count"

index=0;
echo "$ARGS" | while IFS='|' read script image title; do
  # echo "A. [$script] [$image] [$title]"
  script="$(trim $script)"
  image="$(trim $image)"
  title="$(trim $title)"
  if [[ -z "${script:-}" ]]; then continue; fi
  index=$((index+1))
  image_title="$image $index/35"
  echo "[$script] [$image] [$title]"
  Say "Start container for image $image_title"
  container="tls-$index";
  docker rm -f $container 2>/dev/null; docker rm -f $container 2>/dev/null
  docker run --privileged -t --rm -d --hostname $container --name $container "$image" sh -c "while true; do sleep 42; done"
  if [[ "$image" == alpine* ]]; then docker exec -t $container sh -c "apk update --no-progress; apk add --no-progress curl tar sudo bzip2 bash; apk add --no-progress bash icu-libs ca-certificates krb5-libs libgcc libstdc++ libintl libstdc++ tzdata userspace-rcu zlib openssl; echo"; fi
  docker cp $Work/test-sources.sh $container:/test-sources.sh
  for cmd in Say try-and-retry; do
    docker cp /usr/local/bin/$cmd $container:/usr/local/bin/$cmd
  done

  Say "Install sudo, tar, curl|wget, etc into the container [$image_title]"
  echo "Script: [$script]"
  docker exec -t $container bash -c "
      set -e
      echo HOME: \$HOME; 
      source /test-sources.sh;
      $script
      downgrade_open_ssl_3
  "

  net_vers=$NET_VERS; if [[ "$image" == "centos:6"* ]]; then net_vers=$NET_VERS_CENTOS_6; fi
  for netver in $net_vers; do

    # Install TLS checker
    rid=linux-x64
    if [[ "$image" == "alpine"* ]]; then rid=linux-musl-x64; fi
    if [[ "$image" == "centos:6"* ]]; then rid=rhel.6-x64; fi
    export RID=${rid:-} CHECK_TLS_DIR=$Work/check-tls-$netver-$rid; 
    if [[ -d $CHECK_TLS_DIR ]]; then
      Say "Already built: TLS checker [$RID] on the HOST for .NET $netver for [$image_title]"
    else
      PREVPATH="${PREVPATH:-$PATH}"
      DOTNET_CLI_HOME=$Work/dotnet-$netver
      export DOTNET_VERSIONS="$netver" DOTNET_TARGET_DIR=$DOTNET_CLI_HOME SKIP_DOTNET_DEPENDENCIES=True
      script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; 
      export PATH="${DOTNET_CLI_HOME}:${PATH}"

      Say "Install TLS checker [$RID] on the HOST for .NET $netver for [$image_title]"
      url=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/install-tls-checker.sh; 
      try-and-retry bash -c "(wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash"
    fi


    Say "Check TLS on the [$image_title] container for .NET $netver"
    docker cp $CHECK_TLS_DIR $container:/check-tls-$netver
    docker exec -t $container bash -c "
      export DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
      export TLS_REPORT_DIR=/tls-report-$netver;
      if [[ -d /opt/openssl/lib ]]; then export LD_LIBRARY_PATH=/opt/openssl/lib; fi
      /check-tls-$netver/check-tls-core; err=\$?;
      if [ \"\$err\" -ne 0 ]; then
        rm -rf \$TLS_REPORT_DIR/*
        Say \"Retry (2 of 2) TLS Check for NET $netver for $image_title\"
        /check-tls-$netver/check-tls-core
      fi
      true" | tee $Work/tls-report-$title-$netver.txt

    Say "Grab TLS REPORT from [$image_title]"
    report_dir="$Work/TLS-Reports/Net Core $netver on $title"
    mkdir -p "$report_dir"
    rm -rf "$report_dir/*"
    echo $title > "$report_dir/os"
    echo $netver > "$report_dir/net"
    docker cp $container:/tls-report-$netver/. "$report_dir"
    Say "OK: [$image_title]"
  done

  docker rm -f $container 2>/dev/null;
done
