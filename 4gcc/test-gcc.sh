#!/usr/bin/env bash

set -e
set -u
set -o pipefail
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-$HOME/build-agent-artifacts}"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"

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
  apt-get install libpthread-stubs0-dev -y -qq
  local url="https://brick.kernel.dk/snaps/fio-3.27.tar.gz"
  echo "BUILDING FIO: $url"
  local work=/transient-builds/fio-dev
  mkdir -p "$work"
  pushd "$work"

  DOWNLOAD_SHOW_PROGRESS=True
  download_file "$url" _fio-3.27.tar.gz
  tar xzf _fio-3.27.tar.gz
  cd fio* || true
  echo "CURRENT DIRECTORY: [$(pwd)]. Building fio"
  ./configure --prefix=/usr/local $FIO_CONFIGURE_OPTIONS
  make -j |& tee SYSTEM_ARTIFACTSDIRECTORY/fio-make-$FIO_NAME.log
  make install
  Say "fio complete"
  fio --version
  fio --enghelp
}

function build_fio_twice() {
  Say "Static fio build"
  export FIO_CONFIGURE_OPTIONS="" FIO_NAME=shared
  build_fio

  Say "Static fio build"
  export FIO_CONFIGURE_OPTIONS="--build-static" FIO_NAME=static
  # build_fio
}

build_libaio
build_fio_twice

