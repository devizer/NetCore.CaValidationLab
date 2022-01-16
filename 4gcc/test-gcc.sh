#!/usr/bin/env bash

# OK. 10.3, 9.4, 11.1, 11.2, 

set -e
set -u
set -o pipefail
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-$HOME/build-agent-artifacts}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

function wrap_cmd() {
  local key="$1"
  shift
  eval $* |& tee "$SYSTEM_ARTIFACTSDIRECTORY/$key.log"
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
  if [[ "$(command -v wget)" != null ]]; then
    try1="${try1:-} wget $progress1 --no-check-certificate -O '$file' '$url'"
  fi
  if [[ "$(command -v curl)" != null ]]; then
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
  echo "BUILDING LIBAIO: $url"
  local work=/transient-builds/libaio-dev
  mkdir -p "$work"
  pushd "$work"
  DOWNLOAD_SHOW_PROGRESS=True
  download_file "$url" _libaio-libaio-0.3.112.tar.gz
  tar xzf _libaio-libaio-0.3.112.tar.gz
  cd libaio*
  time make prefix=/usr install
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
  rm -rf fio*
  
  DOWNLOAD_SHOW_PROGRESS=True
  test ! -s _fio-${FIO_VER}.tar.gz && download_file "$url" _fio-${FIO_VER}.tar.gz
  tar xzf _fio-${FIO_VER}.tar.gz
  cd fio* || true
  Say "CURRENT DIRECTORY: [$(pwd)]. Building fio"
  ./configure --prefix=/usr/local $FIO_CONFIGURE_OPTIONS
  # make -j |& tee $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME-make.log
  # make install |& tee $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME-make-install.log
  wrap_cmd "fio-$FIO_NAME-make"            make -j
  wrap_cmd "fio-$FIO_NAME-make-install"    make install
  Say "fio complete"
  strip /usr/local/bin/fio 2>/dev/null || true 
  # (command -v fio; fio --version; fio --enghelp) |& tee $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME.log || true
  wrap_cmd "fio-$FIO_NAME-get-version"     fio --version
  wrap_cmd "fio-$FIO_NAME-get-getengines"  fio --enghelp

}

function build_fio_twice() {
  local err
  for FIO_VER in 3.26 3.27 3.28 3.29; do
    rm -f /usr/local/bin/fio
    Say "Static fio build $FIO_VER"
    export FIO_CONFIGURE_OPTIONS="--build-static" FIO_NAME="static-$FIO_VER"
    build_fio || true
    err=$?;
    echo "Exit code: $err" |& tee $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME-exit-code.result
    cp -f /usr/local/bin/fio $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME || true

    rm -f /usr/local/bin/fio
    Say "Shared fio build $FIO_VER"
    export FIO_CONFIGURE_OPTIONS="" FIO_NAME="shared-$FIO_VER"
    build_fio || true
    err=$?;
    echo "Exit code: $err" |& tee $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME-exit-code.result
    cp -f /usr/local/bin/fio $SYSTEM_ARTIFACTSDIRECTORY/fio-$FIO_NAME || true
    rm -f /usr/local/bin/fio
  done
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
  install_openssl_111 > /dev/null
  LD_LIBRARY_PATH="$OPENSSL_HOME/lib" $OPENSSL_HOME/bin/openssl version |& tee $SYSTEM_ARTIFACTSDIRECTORY/openssl-version.log || true
  err=$?;
  echo "Exit code: $err" |& tee $SYSTEM_ARTIFACTSDIRECTORY/openssl-version.result
}

Say "gcc version [$(gcc --version | head -1)]"

# build_open_ssl

build_libaio
build_fio_twice

