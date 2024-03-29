#!/usr/bin/env bash

# OK. 10.3, 9.4, 11.1, 11.2, 
# actually it builds fio matrix

set -e
set -u
set -o pipefail
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-$HOME/build-agent-artifacts}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

function wrap_cmd() {
  local key="$1"
  shift
  mkdir -p "$(dirname "$SYSTEM_ARTIFACTSDIRECTORY/$key.log")"
  eval "$@" |& tee "$SYSTEM_ARTIFACTSDIRECTORY/$key.log"
  local err=$?
  echo "$err" > "$SYSTEM_ARTIFACTSDIRECTORY/$key.result"
}

function download_file() {
  local url="$1"
  local file="$2";
  local progress1="";
  local progress2="";
  if [[ "$DOWNLOAD_SHOW_PROGRESS" != "True" ]] || [[ ! -t 1 ]]; then
    progress1="-q -nv"
    progress2="-s"
  fi
  local try1=""
  if [[ "$(command -v wget)" != "" ]]; then
    try1="wget $progress1 --no-check-certificate -O '$file' '$url'"
  fi
  if [[ "$(command -v curl)" != "" ]]; then
    [[ -n "${try1:-}" ]] && try1="$try1 || "
    try1="${try1:-} curl $progress2 -kSL -o '$file' '$url'"
  fi
  if [[ "${try1:-}" == "" ]]; then
    echo "error: niether curl or wget is available"
    exit 42;
  fi
  eval $try1 || eval $try1 || eval $try1
  # eval try-and-retry wget $progress1 --no-check-certificate -O '$file' '$url' || eval try-and-retry curl $progress2 -kSL -o '$file' '$url'
}


function build_libaio() {
  local url="https://pagure.io/libaio/archive/libaio-0.3.112/libaio-libaio-0.3.112.tar.gz"
  Say "BUILDING LIBAIO: $url"
  local work=/transient-builds/libaio-dev
  mkdir -p "$work"
  pushd "$work"
  DOWNLOAD_SHOW_PROGRESS=True
  download_file "$url" _libaio-libaio-0.3.112.tar.gz
  tar xzf _libaio-libaio-0.3.112.tar.gz
  cd libaio*
  time make prefix=/usr/local install
  wrap_cmd "ldd-libaio.so.1" ldd -v /usr/local/lib/libaio.so.1 || true
  cp /usr/local/lib/libaio.so.1 $SYSTEM_ARTIFACTSDIRECTORY/libaio.so.1 || true
  echo '
  # export CFLAGS="-O2 -I/transient-builds/libaio-dev/include/"
  # export LDFLAGS="-L/transient-builds/libaio-dev/lib/"
  # export LD_LIBRARY_PATH=/transient-builds/libaio-dev/lib
  export FIO_CONFIGURE_OPTIONS="--build-static"
  ' > ~/vars.sh
  popd
}


function build_fio() {
  FIO_VER="${FIO_VER:-3.27}"
  local url="https://brick.kernel.dk/snaps/fio-${FIO_VER}.tar.gz"
  echo "BUILDING FIO: $url"
  local work=/transient-builds/fio-src
  mkdir -p "$work"
  pushd "$work"
  rm -rf *
  
  DOWNLOAD_SHOW_PROGRESS=True
  fio_archive=/tmp/fio-${FIO_VER}.tar.gz
  test ! -s $fio_archive && download_file "$url" $fio_archive
  tar xzf $fio_archive
  cd fio* || true
  Say "CURRENT DIRECTORY: [$(pwd)]. Building fio"
  local key="${FIO_VER}/$FIO_NAME"
  # experimetal c99 for fio 3.29
  CFLAGS=""; if [[ "${FIO_VER}" == "3.29" ]]; then CFLAGS="-std=c99"; fi; 
  export CFLAGS
  wrap_cmd "$key/configure"    ./configure --prefix=/usr/local $FIO_CONFIGURE_OPTIONS
  wrap_cmd "$key/make"         make -j
  wrap_cmd "$key/make-install" make install
  Say "fio complete"
  strip /usr/local/bin/fio 2>/dev/null || true
  cp -f /usr/local/bin/fio $SYSTEM_ARTIFACTSDIRECTORY/$key/fio || true

  # (command -v fio; fio --version; fio --enghelp) |& tee $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME.log || true
  wrap_cmd "$key/get-version"    fio --version
  wrap_cmd "$key/get-getengines" fio --enghelp
  wrap_cmd "$key/ldd"            ldd -v /usr/local/bin/fio

  export LD_LIBRARY_PATH=/usr/local/lib
  for engine in sync libaio posixaio; do
    Say "Test Engine [$engine] of fio ver [$FIO_VER]"
    wrap_cmd "$key/bench-$engine"      fio --name=test --randrepeat=1 --ioengine=$engine --gtod_reduce=1 --filename=$HOME/fio-test.tmp --bs=4k --size=32K --readwrite=read
  done
}

function install_libpthread_dev() {
  # dnf install compat-libpthread-nonshared -y -q - centos8
  # pthread-stubs
  [[ "$(command -v apt-get)" != "" ]] && apt-get install libpthread-stubs0-dev -y -qq
  [[ "$(command -v dnf)" != "" ]]     && dnf install compat-libpthread-nonshared -y -q | cat || true
}

function remove_libpthread_dev() {
  [[ "$(command -v apt-get)" != "" ]] && apt-get purge libpthread-stubs0-dev -y -qq
  [[ "$(command -v dnf)" != "" ]]     && dnf remove --noautoremove --nogpgcheck compat-libpthread-nonshared -y -q | cat || true
}

function build_fio_twice() {
  local err
  local versions="2.21 3.16 3.29 3.28 3.27 3.26"
  for FIO_VER in $versions; do
    
    # SKIP STATIC
    # rm -f /usr/local/bin/fio
    # Say "Static fio build $FIO_VER"
    # export FIO_NAME="$FIO_VER-static" FIO_CONFIGURE_OPTIONS="--build-static"
    # build_fio || true

    rm -f /usr/local/bin/fio
    Say "Shared fio build $FIO_VER"
    export FIO_NAME="$FIO_VER-shared" FIO_CONFIGURE_OPTIONS=""
    build_fio || true
    rm -f /usr/local/bin/fio
  done

  # SKIP STATIC
  # wrap_cmd "install-libpthread-stub" install_libpthread_dev
  # for FIO_VER in $versions; do
    # rm -f /usr/local/bin/fio
    # Say "Static fio build with PTHREAD STUBS $FIO_VER"
    # export FIO_NAME="$FIO_VER-static-with-posixaio" FIO_CONFIGURE_OPTIONS="--build-static"
    # build_fio || true
  # done
}

function build_open_ssl() {
  # ssl 1.1.1
  export OPENSSL_HOME=/opt/openssl-1.1
  Say "Installing OpenSSL 1.1.1m to [$OPENSSL_HOME]"
  script=https://raw.githubusercontent.com/devizer/w3top-bin/master/tests/openssl-1.1-from-source.sh
  file=/tmp/openssl-1.1.1.sh
  try-and-retry wget --no-check-certificate -O $file $script 2>/dev/null || curl -ksSL -o $file $script
  source $file
  Say "System OpenSSL Version: $(get_openssl_system_version)"
  wrap_cmd "openssl-install" eval "install_openssl_111 > /dev/null"
  wrap_cmd "openssl-version" eval "LD_LIBRARY_PATH=\"$OPENSSL_HOME/lib\" $OPENSSL_HOME/bin/openssl version"
}

# FIO_CONFIGURE_OPTIONS="" FIO_VER="2.21" FIO_NAME="fio-default" build_fio

Say "gcc version [$(gcc --version | head -1)]"
Say "LDD VERSION"
wrap_cmd "ldd-version" eval "ldd --version | head -1 | awk '{print \$NF}' || true"
wrap_cmd "gcc-version" eval "echo $(get_gcc_version)"
wrap_cmd "machine" eval "uname -m | head -1 | awk '{print \$NF}' || true"

linux_os_key=$(get_linux_os_key)
wrap_cmd "os" eval "echo ${linux_os_key:-}"

# for deployment
# build_open_ssl || true

build_libaio
build_fio_twice

Say "Pack /usr/local"
/usr/local/uninstall-this-gcc.sh || true
pushd /usr/local
GZIP=-9 tar czf $SYSTEM_ARTIFACTSDIRECTORY/usr-local.tar.gz .
popd

