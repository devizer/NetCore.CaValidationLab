#!/usr/bin/env bash
set -e
set -u
set -o pipefail
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


echo '

fedora_prepare | fedora:24 | Fedora-24
fedora_prepare | fedora:26 | Fedora-26
fedora_prepare | fedora:35 | Fedora-35

pacman -Sy --noconfirm sudo tar | archlinux:base | Arch

gentoo_prepare | gentoo/stage3-amd64-nomultilib | Gentoo

prepare_centos | centos:7.0.1406        | CentOS-7
prepare_centos | centos:6.10            | CentOS-6
prepare_centos | centos:8               | CentOS-8

alpine_prepare | alpine:3.12            | Alpine-3.12
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

' |
while IFS='|' read script image title; do
  # echo "A. [$script] [$image] [$title]"
  script="$(trim $script)"
  image="$(trim $image)"
  title="$(trim $title)"
  if [[ -z "${script:-}" ]]; then continue; fi
  echo "[$script] [$image] [$title]"
  Say "Start image $image"
  docker rm -f w3top 2>/dev/null; docker rm -f w3top 2>/dev/null
  docker run --privileged -t --rm -d --hostname w3top-container --name w3top "$image" sh -c "while true; do sleep 42; done"
  if [[ "$image" == alpine* ]]; then docker exec -t w3top sh -c "apk update --no-progress; apk add --no-progress curl tar sudo bzip2 bash; apk add --no-progress bash icu-libs ca-certificates krb5-libs libgcc libstdc++ libintl libstdc++ tzdata userspace-rcu zlib openssl; echo"; fi
  docker cp $Work/test-sources.sh w3top:/test-sources.sh
  for cmd in Say try-and-retry; do
    docker cp /usr/local/bin/$cmd w3top:/usr/local/bin/$cmd
  done

  Say "Install sudo, tar, curl|wget, etc into the container [$title]"
  echo "Script: [$script]"
  docker exec -t w3top bash -c "
      echo HOME: \$HOME; 
      source /test-sources.sh;
      $script
  "

  net_vers="3.1 5.0 6.0"; if [[ "$image" == "centos:6"* ]]; then net_vers="3.1.120"; fi
  for netver in $net_vers; do
    PREVPATH="${PREVPATH:-$PATH}"
    DOTNET_CLI_HOME=$Work/dotnet-$netver
    export DOTNET_VERSIONS="$netver" DOTNET_TARGET_DIR=$DOTNET_CLI_HOME SKIP_DOTNET_DEPENDENCIES=True
    script=https://raw.githubusercontent.com/devizer/test-and-build/master/lab/install-DOTNET.sh; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash; 
    export PATH="${DOTNET_CLI_HOME}:${PATH}"

    Say "Install TLS checker on the HOST for .NET $netver"
    rid=
    if [[ "$image" == "alpine"* ]]; then rid=linux-musl-x64; fi
    if [[ "$image" == "centos:6"* ]]; then rid=rhel.6-x64; fi
    export RID=${rid:-} CHECK_TLS_DIR=$Work/check-tls-$netver; url=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/install-tls-checker.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash;

    Say "Check TLS on the $image container for .NET $netver"
    docker cp $CHECK_TLS_DIR w3top:/check-tls-$netver
    docker exec -t w3top bash -c "
      export DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=1 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 TLS_REPORT_DIR=/tls-report-$netver;
      /check-tls-$netver/check-tls-core; true" | tee $Work/tls-report-$title-$netver.txt

    Say "Grab TLS REPORT"
    report_dir="$Work/TLS-Reports/Net Core $netver on $title"
    mkdir -p "$report_dir"
    rm -rf "$report_dir/*"
    echo $title > "$report_dir/os"
    echo $netver > "$report_dir/net"
    docker cp w3top:/tls-report-$netver/. "$report_dir"

  done

done
