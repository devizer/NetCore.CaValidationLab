#!/usr/bin/env bash
set -e
set -u
export GCCURL="${GCCURL:-https://ftp.gnu.org/gnu/gcc/gcc-8.5.0/gcc-8.5.0.tar.xz}"
Say "GCC: [$GCCURL]"
Say "Flags: [${FLAGS:-}]"


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

echo '
deb http://archive.debian.org/debian/ wheezy main non-free contrib
deb http://archive.debian.org/debian-security wheezy/updates main non-free contrib
deb http://archive.debian.org/debian wheezy-backports main non-free contrib
# stable-jessie/snapshots/X.XX.X
# deb http://download.mono-project.com/repo/debian stable-wheezy/snapshots/5.10 main
# deb http://download.mono-project.com/repo/debian wheezy main
' > /etc/apt/sources.list
try-and-retry apt-get update -qq

export DEBIAN_FRONTEND=noninteractive
try-and-retry apt-get install build-essential gettext autoconf automake bison flex help2man wget curl m4 pv sudo less nano ncdu tree -y -qq > /dev/null
try-and-retry apt-get install libc6-dev* -y -qq > /dev/null
try-and-retry apt-get install gcc-multilib -y -qq > /dev/null
Say "Completed prerequisites"
work=/transient-builds/gcc-src
SYSTEM_ARTIFACTSDIRECTORY="${SYSTEM_ARTIFACTSDIRECTORY:-$work-articacts}"
Say "SYSTEM_ARTIFACTSDIRECTORY: [$SYSTEM_ARTIFACTSDIRECTORY]"
mkdir -p "$SYSTEM_ARTIFACTSDIRECTORY"
mkdir -p $work
cd $work
wget --no-check-certificate -O _gcc.tar.xz $GCCURL
pv _gcc.tar.xz | tar xJf -
rm -f _gcc.tar.gz
cd gcc*
# export CFLAGS="${FLAGS:-}" CPPFLAGS="${FLAGS:-}" CXXFLAGS="${FLAGS:-}"
contrib/download_prerequisites
args=""; 
if [[ "$(getconf LONG_BIT)" != "32" ]]; then args="--disable-multilib"; fi
./configure --prefix=/usr/local $args |& tee "$SYSTEM_ARTIFACTSDIRECTORY/configure.log"
cpus=$(nproc)
# cpus=$((cpus+1))
# if [[ "$(uname -m)" == "armv7"* ]]; then cpus=3; fi
time make -j${cpus} |& tee "$SYSTEM_ARTIFACTSDIRECTORY/make.log"
time make install-strip |& tee "$SYSTEM_ARTIFACTSDIRECTORY/make-install-strip.log"
bash -c "gcc --version" |& tee "$SYSTEM_ARTIFACTSDIRECTORY/gcc-version.log"
