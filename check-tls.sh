#!/usr/bin/env bash
rid=linux-x64
if [[ $(uname -m) == armv7* ]]; then rid=linux-arm; elif [[ $(uname -m) == aarch64 ]]; then rid=linux-arm64; elif [[ $(uname -m) == x86_64 ]]; then rid=linux-x64; fi; if [[ $(uname -s) == Darwin ]]; then rid=osx-x64; fi;
echo Self-Contained rid is \[$rid\]

work=/tmp/check-tls-core
rm -rf $work
mkdir -p $work
pushd $work
dotnet new console --no-restore
url=https://raw.githubusercontent.com/devizer/NetCore.CaValidationLab/master/CaValidationLab/Program.cs; (wget -q -nv --no-check-certificate -O - $url 2>/dev/null || curl -ksSL $url) > Program.cs
dotnet restore
time dotnet run -c Release
time dotnet publish -c Release --self-contained -o out -r $rid && out/check-tls-core
rm -rf bin obj out
popd
