#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

function get_cpu_name() {
  # onbly x86_64. TODO: add arm
  local cpu="$(cat /proc/cpuinfo | grep -E '^model name' | awk -F':' 'NR==1 {print $2}')"
  cpu="$(echo -e "${cpu:-}" | sed -e 's/^[[:space:]]*//')"
  echo "${cpu:-}"
}

function say_cpu_name() {
  Say "CPU: [$(get_cpu_name)]"
}


function prepare_os() {
  Say "Provisioning container..."
  test -f /etc/os-release && source /etc/os-release
  local os_ver="${ID:-}:${VERSION_ID:-}"
  if [[ "${os_ver}" == "debian:7" ]]; then
echo '
Acquire::Check-Valid-Until "0";
APT::Get::Assume-Yes "true";
APT::Get::AllowUnauthenticated "true";
Acquire::AllowInsecureRepositories "1";
Acquire::AllowDowngradeToInsecureRepositories "1";
Acquire::CompressionTypes::Order { "gz"; };
APT::NeverAutoRemove:: ".*";
# APT::Compressor::gzip::CompressArg:: "-1";
# APT::Compressor::xz::CompressArg:: "-1";
# APT::Compressor::bzip2::CompressArg:: "-1";
# APT::Compressor::lzma::CompressArg:: "-1";
' > /etc/apt/apt.conf.d/99Z_Custom

echo '
deb http://archive.debian.org/debian/ wheezy main non-free contrib
deb http://archive.debian.org/debian-security wheezy/updates main non-free contrib
deb http://archive.debian.org/debian wheezy-backports main non-free contrib
' > /etc/apt/sources.list
  fi

  if [[ "${ID:-}" = "debian" ]]; then
    try-and-retry apt-get update -qq
    try-and-retry apt-get install build-essential gettext autoconf automake bison flex help2man wget curl m4 pv sudo less nano ncdu tree -y -qq > /dev/null
    try-and-retry apt-get install libc6-dev* -y -qq > /dev/null
    try-and-retry apt-get install gcc-multilib -y -qq > /dev/null

    # old gcc 4.7 needs LANG and LC_ALL
    apt-get install g++ -y -qq > /dev/null
    apt-get install gawk -y -qq > /dev/null
    apt-get install m4 -y -qq > /dev/null
    Say "Configure LANG and LC_ALL"
    apt-get install locales -y -qq > /dev/null

echo '
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
' > /etc/locale.gen 
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales
  export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  Say "LANG=$LANG LC_ALL=$LC_ALL"
  fi

  Say "Completed system prerequisites"
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


function build_all_known_hash_sums() {
  local file="$1"
  for alg in md5 sha1 sha224 sha256 sha384 sha512; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      local sum=$(eval ${alg}sum $1 | awk '{print $1}')
      printf "$sum" > "$1.${alg}"
    else
      echo "warning! ${alg}sum missing"
    fi
  done
}
