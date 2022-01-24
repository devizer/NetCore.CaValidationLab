#!/usr/bin/env bash
# --target=$TARGET --with-arch=$ARCH --with-fpu=$FPU --with-float=hard --enable-languages=$LANGUAGES --disable-multilib
# armv7: --with-fpu=vfp --with-float=hard
# ARCH: armv6|armv7-a|armv8-a, $FPU=vfp|neon-vfpv4|neon-fp-armv8
# TARGET=aarch64-linux-gnu|arm-linux-gnueabihf
         
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
try-and-retry wget --no-check-certificate -O _gcc.tar $GCCURL
[[ "$GCCURL" == *".bz2" ]] && pv _gcc.tar | tar xjf -
[[ "$GCCURL" == *".xz" ]]  && pv _gcc.tar | tar xJf -
[[ "$GCCURL" == *".gz" ]]  && pv _gcc.tar | tar xzf -
rm -f _gcc.tar*
cd gcc*
# export CFLAGS="${FLAGS:-}" CPPFLAGS="${FLAGS:-}" CXXFLAGS="${FLAGS:-}"
# 32 bit OS: https://stackoverflow.com/a/18190496/15524858
# export C_INCLUDE_PATH="/usr/include/$(gcc -print-multiarch)"
# Say "C_INCLUDE_PATH: [$C_INCLUDE_PATH]"
contrib/download_prerequisites
args="";

# if [[ "$(getconf LONG_BIT)" != "32" ]]; then args="--disable-multilib"; fi
# if [[ "$GCCURL" == *"gcc-4.7"* ]]; then args="--disable-multilib"; fi
# if [[ "$(uname -m)" == "aarch64" ]]; then args="--disable-multilib"; fi

args="--disable-multilib"
# next is for armv7 only
if [[ "$(getconf LONG_BIT)" != "32" ]]; then args="${args:-} --with-fpu=vfp --with-float=hard"; fi

if [[ -n "${ENABLE_LANGUAGES:-}" ]]; then langs_arg="--enable-languages=${ENABLE_LANGUAGES:-}"; fi
./configure --prefix=/usr/local ${langs_arg:-} ${args:-} |& tee "$SYSTEM_ARTIFACTSDIRECTORY/configure.log"
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
