#!/usr/bin/env bash
set -e
set -u
export GCCURL="${GCCURL:-https://ftp.gnu.org/gnu/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz}"
Say "TARGET GCC: [$GCCURL], Using GCC: [${USEGCC:-}]"
Say "Flags: [${FLAGS:-}]"

if [[ "${USEGCC:-}" != "" ]]; then
  export GCC_INSTALL_VER="${USEGCC}" GCC_INSTALL_DIR=/usr/local; 
  Say "Installing GCC ${USEGCC} into $GCC_INSTALL_DIR"
  script=https://sourceforge.net/projects/gcc-precompiled/files/install-gcc.sh/download; (wget -q -nv --no-check-certificate -O - $script 2>/dev/null || curl -ksSL $script) | bash
  Say "GCC VERSION: [$(gcc --version | head -1)]"
fi

work=/transient-builds/gcc-src
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-$work-articacts}"
Say "SYSTEM_ARTIFACTSDIRECTORY: [$SYSTEM_ARTIFACTSDIRECTORY]"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"
mkdir -p $work
cd $work
try-and-retry wget --no-check-certificate -O _gcc.tar.xz $GCCURL
[[ "$GCCURL" == *".bz2" ]] && pv _gcc.tar.xz | tar xjf -
[[ "$GCCURL" == *".xz" ]]  && pv _gcc.tar.xz | tar xJf -
rm -f _gcc.tar.*
cd gcc*
# export CFLAGS="${FLAGS:-}" CPPFLAGS="${FLAGS:-}" CXXFLAGS="${FLAGS:-}"
contrib/download_prerequisites
args="";
if [[ "$(getconf LONG_BIT)" != "32" ]]; then args="--disable-multilib"; fi
if [[ "$GCCURL" == *"gcc-4.7"* ]]; then args="--disable-multilib"; fi
./configure --prefix=/usr/local $args |& tee "$SYSTEM_ARTIFACTSDIRECTORY/configure.log"
cpus=$(nproc)
# cpus=$((cpus+1))
# if [[ "$(uname -m)" == "armv7"* ]]; then cpus=3; fi
time make -j${cpus} |& tee "$SYSTEM_ARTIFACTSDIRECTORY/make.log"
if [[ -f /usr/local/uninstall-this-gcc.sh ]]; then
    Say "Uninstalling prev gcc"
    /usr/local/uninstall-this-gcc.sh --verbose
fi
time make install-strip |& tee "$SYSTEM_ARTIFACTSDIRECTORY/make-install-strip.log"
bash -c "gcc --version" |& tee "$SYSTEM_ARTIFACTSDIRECTORY/gcc-version.log"
