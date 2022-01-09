#!/usr/bin/env bash
# one liner
# url=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/install-tls-checker.sh; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) | bash
set -e
set -u
set -o pipefail
TARGET_DIR=${TARGET_DIR:/~/bin/check-tls}
rid=linux-x64
if [[ $(uname -m) == armv7* ]]; then rid=linux-arm; elif [[ $(uname -m) == aarch64 ]]; then rid=linux-arm64; elif [[ $(uname -m) == x86_64 ]]; then rid=linux-x64; fi; if [[ $(uname -s) == Darwin ]]; then rid=osx-x64; fi;
echo Self-Contained rid is \[$rid\]

work=/tmp/check-tls-core
rm -rf $work
mkdir -p $work
pushd $work >/dev/null
dotnet new console --no-restore
rm -f Program.cs
url=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/CaValidationLab/Program.cs; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) > Program.cs
dotnet restore
# time dotnet run -c Release
time dotnet publish -c Release --self-contained -o out -r $rid
cp -r -f out/ $TARGET_DIR
rm -rf bin obj out
popd >/dev/null
