#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Return temp json file name or epty string
function Get-Docker-Image-Manifest() {
  local image="${1}"
  local json_file="$(mktemp || echo "${TMPDIR:-/tmp/a-docker-image-manifest}")"
  local err=0;
  docker buildx imagetools inspect --raw "$image" >"$json_file" ||
  docker manifest inspect "$image" >"$json_file" || err=$?
  if [[ "$err" -eq 0 ]]; then
    echo "$json_file"
  else 
    rm -f "$json_file"
  fi
}

# stdin - json manifests
function Docker-Image-Manifest-As-Raw-Table() {
  local f='.manifests | map({"size":.size?|tostring, "digest":.digest?, "os":.platform?.os?, "architecture":.platform?.architecture?, "variant":.platform?.variant?}) | map([.os, .architecture, .variant, .digest, .size] | join("|")) | join("\n") '
  jq -r "$f"
}

# stdin - json manifests
function Docker-Image-Manifest-As-Table() {
  local os architecture variant digest size
  Docker-Image-Manifest-As-Raw-Table | while IFS='|' read os architecture variant digest size; do
    local short_os="$os"
    [[ -n "$architecture" ]] && short_os="$short_os/$architecture"
    [[ -n "$variant" ]] && short_os="$short_os/$variant"
    echo -e "$short_os|$digest|$size"
  done
}

# stdin - json manifests
# argument: amd64 arm64 armv7 arm/v7 armv6 arm/v6 armv5 arm/v5 i386 s390x ppc64le mips64le 
function Find-Docker-Image-Digest-for-Architecture() {
  local arch="$1"; 
  local filter='linux\/'"${arch//\//\\\/}"
  # [[ "$arch" == "amd64" ]] && filter="linux\/amd64"
  # [[ "$arch" == "arm64" ]] && filter="linux\/arm64"
  [[ "$arch" == "armv7" ]] && filter='linux\/arm\/v7'
  [[ "$arch" == "armv6" ]] && filter='linux\/arm\/v6'
  [[ "$arch" == "armv5" ]] && filter='linux\/arm\/v5'
  Docker-Image-Manifest-As-Table | awk -F'|' '$1 ~ /^'$filter'/ {print $2}'
}

QEMU_USER_STATIC_DIR="${QEMU_USER_STATIC_DIR:-$HOME/bin/qemu-user-static}"
function Get-Docker-Volumes-For-MultiArch() {
  local qemu_ver="${1:-latest}"
  local container="qemu-user-static-${qemu_ver}"
  local image="multiarch/qemu-user-static:${qemu_ver}"
  local dir="$QEMU_USER_STATIC_DIR/${qemu_ver}"
  if [[ ! -s "${dir}.ok" ]]; then
    Say "Pull $image" 1>&2
    docker pull -q $image
    mkdir -p "$dir"
    Say "Grab qe-user-static ${qemu_ver}" 1>&2
    docker run --name "$container" multiarch/qemu-user-static >/dev/null 2>&1
    docker cp "$container":/usr/bin/. "$dir" >/dev/null 2>&1
    echo "ok" > "${dir}.ok"
  fi
  local ret="";
  pushd "$dir" >/dev/null
  for file in qemu-*-static; do
    [[ -n "$ret" ]] && ret="$ret "
    ret="$ret -v $dir/$file:/usr/bin/$file"
  done
  popd >/dev/null
  echo $ret
}

# Say "[[$(Get-Docker-Volumes-For-MultiArch 5.1.0-2)]]"

function Help-Docker-Image-Manifest() {
  set -e 
  set -u
  local image json arch
  for image in debian:8 debian:11 fedora:24 fedora:35 devizervlad/crossplatform-azure-pipelines-agent; do
    local json="$(Get-Docker-Image-Manifest "$image")"
    Say    "Raw $image"; 
    cat "$json" | Docker-Image-Manifest-As-Raw-Table

    Say "Beauty $image"; 
    cat "$json"  | Docker-Image-Manifest-As-Table

    for arch in amd64 arm64 armv7 arm/v7 armv6 arm/v6 armv5 arm/v5 i386 s390x ppc64le mips64le; do
      Say "$arch: $(cat "$json" | Find-Docker-Image-Digest-for-Architecture "$arch")"
    done

    
  done
}

# Help-Docker-Image-Manifest


# arg1: absolute or relative path, default is current 
function Get-Sub-Directories-As-Names-Only() {
  local path="${1:-.}" line
  pushd "$path" >/dev/null
  find . -maxdepth 1 -type d | grep -v -E '^\.$' | sort -V | while IFS='' read line; do
    echo "${line:2}"
  done
  popd >/dev/null
}

# arg1: absolute or relative path, default is current 
function Get-Sub-Directories-As-Full-Names() {
  local path="${1:-.}" line
  pushd "$path" > /dev/null; local full_path_name="$(pwd)"; popd > /dev/null
  local prefix="$full_path_name"
  [[ "$prefix" == "/" ]] && prefix="";
  Get-Sub-Directories-As-Names-Only "$full_path_name" | while IFS='' read line; do
    echo "$prefix/$line"
  done
}

function get_cpu_name() {
  # only x86_64 and arm
  local cpu="$(cat /proc/cpuinfo | grep -E '^(model name|Hardware)' | awk -F':' 'NR==1 {print $2}')"
  cpu="$(echo -e "${cpu:-}" | sed -e 's/^[[:space:]]*//')"
  echo "${cpu:-}"
}

function say_cpu_name() {
  Say "CPU: [$(get_cpu_name)]"
}

function get_gcc_version() {
  local gcc_version=""
  local cfile="$HOME/temp_show_gcc_version"
  rm -f "$cfile"
  cat <<-'EOF_SHOW_GCC_VERSION' > "$cfile.c"
#include <stdio.h>
int main() { printf("%d.%d.%d\n", __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__); }
EOF_SHOW_GCC_VERSION
  gcc_version="$(gcc $cfile.c -o $cfile 2>/dev/null && $cfile)"
  rm -f "$cfile"; rm -f "$cfile.c" 
  echo "${gcc_version:-}"
}

# returns 21900 for debian 8
function get_glibc_version() {
  GLIBC_VERSION=""
  GLIBC_VERSION_STRING="$(ldd --version 2>/dev/null| awk 'NR==1 {print $NF}')"
  # '{a=$1; gsub("[^0-9]", "", a); b=$2; gsub("[^0-9]", "", b); if ((a ~ /^[0-9]+$/) && (b ~ /^[0-9]+$/)) {print a*10000 + b*100}}'
  local toNumber='{if ($1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/) { print $1 * 10000 + $2 * 100 }}'
  GLIBC_VERSION="$(echo "${GLIBC_VERSION_STRING:-}" | awk -F'.' "$toNumber")"

  if [[ -z "${GLIBC_VERSION:-}" ]] && [[ -n "$(command -v gcc)" ]]; then
    local cfile="$HOME/temp_show_glibc_version"
    rm -f "$cfile"
    cat <<-'EOF_SHOW_GLIBC_VERSION' > "$cfile.c"
#include <gnu/libc-version.h>
#include <stdio.h>
int main() { printf("%s\n", gnu_get_libc_version()); }
EOF_SHOW_GLIBC_VERSION
    GLIBC_VERSION_STRING="$(gcc $cfile.c -o $cfile 2>/dev/null && $cfile)"
    rm -f "$cfile"; rm -f "$cfile.c" 
    GLIBC_VERSION="$(echo "${GLIBC_VERSION_STRING:-}" | awk -F'.' "$toNumber")"
  fi
  echo "${GLIBC_VERSION:-}"
}

# glibc_version=$(get_glibc_version) && echo "GLIBC_VERSION: [${GLIBC_VERSION:-}]; GLIBC_VERSION_STRING: [${GLIBC_VERSION_STRING:-}]"

function adjust_os_repo() {
  Say "Adjust os repo for [$(get_linux_os_id) $(uname -m)]"
  test -f /etc/os-release && source /etc/os-release
  local os_ver="${ID:-}:${VERSION_ID:-}"
  if [[ "${ID:-}" == "debian" ]]; then
echo '
Acquire::Check-Valid-Until "0";
APT::Get::Assume-Yes "true";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "1";
Acquire::AllowDowngradeToInsecureRepositories "1";
Acquire::CompressionTypes::Order { "gz"; };
APT::NeverAutoRemove:: ".*";
APT::Compressor::gzip::CompressArg:: "-1";
APT::Compressor::xz::CompressArg:: "-1";
APT::Compressor::bzip2::CompressArg:: "-1";
APT::Compressor::lzma::CompressArg:: "-1";
' > /etc/apt/apt.conf.d/99Z_Custom
  fi

  if [[ "${os_ver}" == "debian:7" ]]; then
echo '
deb http://archive.debian.org/debian/ wheezy main non-free contrib
deb http://archive.debian.org/debian-security wheezy/updates main non-free contrib
deb http://archive.debian.org/debian wheezy-backports main non-free contrib
' > /etc/apt/sources.list
  fi

  if [[ "${os_ver}" == "debian:7" ]] && [[ "$(getconf LONG_BIT)" == 32 ]] ; then
echo '
deb http://archive.debian.org/debian/ wheezy main non-free contrib
deb http://archive.debian.org/debian-security wheezy/updates main non-free contrib
deb http://archive.debian.org/debian wheezy-backports main non-free contrib
' > /etc/apt/sources.list
  fi

echo 'JESSIE x86_64:
# deb http://snapshot.debian.org/archive/debian/20210326T030000Z jessie main
deb http://deb.debian.org/debian jessie main
# deb http://snapshot.debian.org/archive/debian-security/20210326T030000Z jessie/updates main
deb http://security.debian.org/debian-security jessie/updates main
# deb http://snapshot.debian.org/archive/debian/20210326T030000Z jessie-updates main
deb http://deb.debian.org/debian jessie-updates main
'>/dev/null

  if [[ "${os_ver}" == "debian:8" ]] && [[ "$(getconf LONG_BIT)" == "64" ]] && [[ "$(uname -m)" != x86_64 ]]; then
echo '
deb http://archive.debian.org/debian/ jessie main non-free contrib
# deb http://archive.debian.org/debian-security jessie/updates main non-free contrib
deb http://archive.debian.org/debian jessie-backports main non-free contrib
' > /etc/apt/sources.list
  fi

  if [[ "${os_ver}" == "debian:8" ]] && [[ "$(getconf LONG_BIT)" == "32" ]]; then
echo '
deb http://archive.debian.org/debian/ jessie main non-free contrib
deb http://security.debian.org/ jessie/updates main contrib non-free
deb http://archive.debian.org/debian jessie-backports main non-free contrib
' > /etc/apt/sources.list
  fi

  if [[ "$(get_linux_os_id)" == "centos:8" ]]; then
    Say "Resetting CentOS 8 Repo"
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Linux-*
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-Linux-*
  fi


  if [[ "$(get_linux_os_id)" == "centos:6" ]]; then
  Say "Resetting CentOS 6 Repo"
cat <<-'CENTOS6_REPO' > /etc/yum.repos.d/CentOS-Base.repo
[C6.10-base]
name=CentOS-6.10 - Base
baseurl=http://vault.centos.org/6.10/os/$basearch/
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=1
metadata_expire=never

[C6.10-updates]
name=CentOS-6.10 - Updates
baseurl=http://vault.centos.org/6.10/updates/$basearch/
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=1
metadata_expire=never

[C6.10-extras]
name=CentOS-6.10 - Extras
baseurl=http://vault.centos.org/6.10/extras/$basearch/
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=1
metadata_expire=never

[C6.10-contrib]
name=CentOS-6.10 - Contrib
baseurl=http://vault.centos.org/6.10/contrib/$basearch/
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=0
metadata_expire=never

[C6.10-centosplus]
name=CentOS-6.10 - CentOSPlus
baseurl=http://vault.centos.org/6.10/centosplus/$basearch/
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
enabled=0
metadata_expire=never
CENTOS6_REPO
  fi

  if [[ "$(command -v dnf)" != "" ]] || [[ "$(command -v yum)" != "" ]]; then
    # centos/redhat/fedora
    if [[ -d /etc/yum.repos.d ]]; then
      Say "Switch off gpgcheck for /etc/yum.repos.d/*.repo for [$(get_linux_os_id) $(uname -m)]"
      sed -i "s/gpgcheck=1/gpgcheck=0/g" /etc/yum.repos.d/*.repo
    fi

    if [[ -e /etc/dnf/dnf.conf ]]; then
      Say "Switch off gpgcheck for /etc/dnf/dnf.conf for [$(get_linux_os_id) $(uname -m)]"
      sed -i "s/gpgcheck=1/gpgcheck=0/g" /etc/dnf/dnf.conf
    fi
  fi

  if [[ "$(get_linux_os_id)" == "centos"* ]]; then
    Say "Update yum cache for [$(get_linux_os_id) $(uname -m)]"
    try-and-retry yum makecache -q
  fi

  if [[ -n "$(command -v apt-get)" ]]; then
    Say "Update apt cache for [$(get_linux_os_id) $(uname -m)]"
    try-and-retry apt-get update -qq
  fi

  echo '
  export NCURSES_NO_UTF8_ACS=1 PS1="\[\033[01;35m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \$\[\033[00m\] "
' | tee -a ~/.bashrc >/dev/null

}

function configure_os_locale() {
  
  # LANG & LC_ALL
  if [[ "$(command -v dnf)" != "" ]] || [[ "$(command -v yum)" != "" ]] || [[ "$(command -v zypper)" != "" ]]; then
    if [[ -n "$(command -v locale)" ]]; then
      local l="$(locale -a | grep -i 'en_us\.utf8')"
      if [[ -n "${l:-}" ]]; then
        Say "[suse/centos/redhat/fedora] Configure LC_ALL and LANG as [$l] for [$(get_linux_os_id) $(uname -m)]"
        export LC_ALL="$l" LANG="$l"
        Say "LANG=$LANG LC_ALL=$LC_ALL"
      fi
    fi
  fi

  if [[ "$(command -v apt-get)" != "" ]]; then
echo '
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
' > /etc/locale.gen 

    Say "[debian/ubuntu] Configure LANG and LC_ALL and install **libicu** for [$(get_linux_os_id) $(uname -m)]"
    apt-get install locales mc -y -q >/dev/null

    # DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales
    export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
    Say "LANG=$LANG LC_ALL=$LC_ALL"
  fi

}

function prepare_os() {
  PREPARE_OS_MODE="${PREPARE_OS_MODE:-BIG}"
  adjust_os_repo
  Say "Provisioning container for [$(get_linux_os_id) $(uname -m)], PREPARE_OS_MODE is ${PREPARE_OS_MODE:-}"

  if [[ "$(command -v dnf)" != "" ]]; then
    try-and-retry dnf install gcc make autoconf libtool curl wget mc nano less -y -q >/dev/null
  elif [[ "$(command -v yum)" != "" ]]; then
    try-and-retry yum install gcc make autoconf libtool curl wget mc nano less ncdu -y -q >/dev/null
  fi

  if [[ "$(command -v apt-get)" != "" ]]; then
    try-and-retry apt-get update -qq >/dev/null
    
    [[ "${PREPARE_OS_MODE:-}" == "BIG" ]] && try-and-retry apt-get install \
       ca-certificates curl aria2 gnupg software-properties-common htop mc lsof unzip \
       net-tools bsdutils lsb-release wget curl pv sudo less nano ncdu tree \
       procps dialog \
       build-essential libc6-dev libtool gettext autoconf automake bison flex help2man m4 \
       pkg-config g++ gawk \
       -y -q >/dev/null

    [[ "${PREPARE_OS_MODE:-}" == "MICRO" ]] && try-and-retry apt-get install \
       curl aria2 htop mc lsof gawk gnupg openssh-client openssl \
       bsdutils lsb-release xz-utils pv sudo less nano ncdu tree \
       procps dialog \
       -y -q >/dev/null
    # try-and-retry apt-get install -y -q >/dev/null #* 

    # gcc-multilib is optional
    if [[ "${PREPARE_OS_MODE:-}" == "BIG" ]]; then
        local multilib="$(apt-cache search gcc-multilib | grep -E "gcc-multilib\ " | awk '{print $1}')"
        if [[ -n "${multilib:-}" ]]; then
          # Say "Installing the gcc-multilib package"
          try-and-retry apt-get install gcc-multilib -y -q >/dev/null
        fi
    fi

  fi

  if [[ "$(command -v zypper)" != "" ]]; then
    Say "Refresh zypper metadata for [$(get_linux_os_id) $(uname -m)]"
    zypper -n refresh >/dev/null
    Say "Install curl sudo mc nano htop for [$(get_linux_os_id) $(uname -m)]"
    zypper -n install -y curl sudo mc nano ncdu htop coreutils git pv jq gcc gettext-runtime autoconf automake bison flex help2man m4 pv jq sudo less nano ncdu tree >/dev/null
  fi

  configure_os_locale
  Say "Completed system prerequisites for [$(get_linux_os_id) $(uname -m)]"

}

function install_precompiled_gcc() {
  local ver="${1:-}"
  if [[ "${ver:-}" != "" ]]; then
    export GCC_INSTALL_VER="${ver}" GCC_INSTALL_DIR="${GCC_INSTALL_DIR:-/usr/local}"; 
    # script=https://sourceforge.net/projects/gcc-precompiled/files/install-gcc.sh/download; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
    Say "Installing Precompiled GCC ver ${ver} into [${GCC_INSTALL_DIR}]"
    script="https://master.dl.sourceforge.net/project/gcc-precompiled/install-gcc.sh?viasf=1"; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
  else
    Say "Skip precompiled gcc installation. Use system gcc"
  fi
}


function generate_uninstall_this_gcc() {
  file="$1"
  to="$2"
  printf '#!/usr/bin/env bash
      [[ "$1" == "--verbose" ]] && Is_Verbose=true;
      pushd "$(dirname "$0")" > /dev/null; ScriptPath="$(pwd)"; popd > /dev/null
      pushd "$ScriptPath" >/dev/null
      # it iss an output of tar cf gcc.tar.xz
      Files='"'"> "$to"

  cat "$file" | gzip -f -d | tar tf - | while IFS= read -r line; do
    # if 0 || [[ "${line: -1}" != "/" ]] && [[ "${line}" != "./man" ]]; then
      # echo 'test -f "'$line'" && (rm -f "'$line'" || sudo rm -f "'$line'" 2>/dev/null)' >> "$to"
      echo $line >> "$to"
    # fi
  done

cat <<-'EOF' >> "$to"
'
    for file in $Files; do
      if [[ -L "$file" ]]; then
        if [[ -f "$(readlink -f "$file")" ]]; then 
          [[ "$Is_Verbose" == true ]] && echo "deleting a link to a file: [$file]"; 
          rm -f "$file";
        fi
      fi
    done
    for file in $Files; do
      if [[ -f "$file" ]]; then
        [[ "$Is_Verbose" == true ]] && echo "deleting a regular file: [$file]"; 
        rm -f "$file"
      fi
    done

    popd >/dev/null
EOF

chmod +x "$to"
}

function _ignore_a_local_test_ () {
tar xzf 1.tar.gz
generate_uninstall_this_gcc 1.tar.gz uninstall-this-gcc.sh
./uninstall-this-gcc.sh --verbose | tee uninstall.log
nano uninstall.log
}

function get_linux_os_id() {
  # RHEL: ID="rhel" VERSION_ID="7.5" PRETTY_NAME="Red Hat Enterprise Linux" (without version)
  test -e /etc/os-release && source /etc/os-release
  local ret="${ID:-}:${VERSION_ID:-}"
  ret="${ret//[ ]/}"

  if [ -e /etc/redhat-release ]; then
    local redhatRelease=$(</etc/redhat-release)
    if [[ $redhatRelease == "Red Hat Enterprise Linux Server release 6."* ]]; then
      ret="rhel:6"
    fi
    if [[ $redhatRelease == "CentOS release 6."* ]]; then
      ret="centos:6"
    fi
  fi
  [[ "${ret:-}" == ":" ]] && ret="linux"
  echo "${ret}"
}

# safe file name
function get_linux_os_key() {
  # RHEL: ID="rhel" VERSION_ID="7.5" PRETTY_NAME="Red Hat Enterprise Linux" (without version)
  test -e /etc/os-release && source /etc/os-release
  local ret="${ID:-}"
  if [[ -n "${VERSION_ID:-}" ]]; then ret="${ret}_${VERSION_ID:-}"; fi
  if [[ -n "${VERSION_CODENAME:-}" ]]; then ret="${ret}_${VERSION_CODENAME:-}"; fi
  ret="${ret//[ ]/}"

  if [ -e /etc/redhat-release ]; then
    local redhatRelease=$(</etc/redhat-release)
    if [[ $redhatRelease == "Red Hat Enterprise Linux Server release 6."* ]]; then
      ret="rhel_6"
    fi
    if [[ $redhatRelease == "CentOS release 6."* ]]; then
      ret="centos_6"
    fi
  fi
  [[ -z "${ret:-}" ]] && ret="linux"
  echo "${ret}"
}

function build_all_known_hash_sums() {
  local file="$1"
  for alg in md5 sha1 sha224 sha256 sha384 sha512; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      local sum=$(eval ${alg}sum "'"$file"'" | awk '{print $1}')
      printf "$sum" > "$file.${alg}"
    else
      echo "warning! ${alg}sum missing"
    fi
  done
}

function build_all_known_hash_sums_for_list_of_files() {
  # centos: yum install fipscheck isomd5sum -y
  while IFS='' read file; do
    for alg in md5 sha1 sha224 sha256 sha384 sha512; do
      if [[ "$(command -v ${alg}sum)" != "" ]]; then
        local sum=$(eval ${alg}sum "'"$file"'" | awk '{print $1}')
        echo "$(basename "${file}") ${alg} ${sum}"
      else
        echo "warning! ${alg}sum missing"
      fi
    done
  done
}
