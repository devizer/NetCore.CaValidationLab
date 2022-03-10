#!/usr/bin/env bash
# --target=$TARGET --with-arch=$ARCH --with-fpu=$FPU --with-float=hard --enable-languages=$LANGUAGES --disable-multilib
# armv7: --with-fpu=vfp --with-float=hard
# ARCH: armv6|armv7-a|armv8-a, $FPU=vfp|neon-vfpv4|neon-fp-armv8
# TARGET=aarch64-linux-gnu|arm-linux-gnueabihf

# OK ARM32v7: https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/21d9f648982054e55d294a16256c6d8ad9c61287/4gcc/build-gcc-task.sh
         
set -e
set -u

  export VER=8.5.0
  Say "Build $VER"
  export GCCURL=https://ftp.gnu.org/gnu/gcc/gcc-$VER/gcc-$VER.tar.xz
  export SYSTEM_ARTIFACTSDIRECTORY=$HOME/GCC-ARTIFACTS-$VER
  mkdir -p $SYSTEM_ARTIFACTSDIRECTORY
  export ENABLE_LANGUAGES="c,c++" FLAGS="-O0"
  Say "ENABLE_LANGUAGES: $ENABLE_LANGUAGES"

export ENABLE_LANGUAGES="c,c++" # without docker aka on termux
DEFAULT_GCC_VER=10.3.0
export GCCURL="${GCCURL:-https://ftp.gnu.org/gnu/gcc/gcc-${DEFAULT_GCC_VER}/gcc-${DEFAULT_GCC_VER}.tar.xz}"
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
mkdir -p $work; 
rm -rf $work/* 2>/dev/null; rm -rf $work/* 2>/dev/null; rm -rf $work/* # termux is wierd
cd $work
try-and-retry aria2c --allow-overwrite=true --check-certificate=false -s 9 -x 9 -k 3M -j 9 -d $(pwd) -o _gcc.tar "$GCCURL" || try-and-retry wget --no-check-certificate -O _gcc.tar $GCCURL
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
if [[ "$(uname -m)" == "aarch64" ]] || [[ "$(uname -m)" == "arm"* ]]; then
  # https://wiki.segger.com/GCC_floating-point_options
  # armv7
  if [[ "$(getconf LONG_BIT)" == "32" ]] && [[ "$(uname -m)" == armv7* ]]; then args="${args:-} --with-fpu=vfpv3 --with-float=hard"; fi
  # armv5
  if [[ "$(getconf LONG_BIT)" == "32" ]] && [[ "$(uname -m)" == armv5* ]]; then args="${args:-} --with-arch=armv4t --with-float=soft  --build=arm-linux-gnueabi --host=arm-linux-gnueabi --target=arm-linux-gnueabi"; fi
fi
if [[ -n "${ENABLE_LANGUAGES:-}" ]]; then langs_arg="--enable-languages=${ENABLE_LANGUAGES:-}"; fi
echo "ARGS: ${langs_arg:-} ${args:-}" > "$SYSTEM_ARTIFACTSDIRECTORY/configure-args.txt"
Say "ARGS: ${langs_arg:-} ${args:-}"
export CC=clang CXX=clang++ CFLAGS="-O2" LDFLAGS="-static -all-static"
./configure --prefix=/opt/gcc-$VER ${langs_arg:-} ${args:-} |& tee "$SYSTEM_ARTIFACTSDIRECTORY/configure.log"
cpus=$(nproc)
time make CC=clang CXX=clang++ CFLAGS="-O2" LDFLAGS="-static -all-static" -j${cpus} |& tee "$SYSTEM_ARTIFACTSDIRECTORY/make.log"
time make -j${cpus} install-strip |& tee "$SYSTEM_ARTIFACTSDIRECTORY/make-install-strip.log"

# bash -c "gcc --version" |& tee "$SYSTEM_ARTIFACTSDIRECTORY/gcc-version.log"

