#!/usr/bin/env bash
rid=linux-x64
if [[ $(uname -m) == armv7* ]]; then rid=linux-arm; fi; 
if [[ $(uname -m) == aarch64 ]]; then rid=linux-arm64; fi; 
echo Self-Contained rid is \[$rid\]

pushd /tmp
cd $(mktemp -d CaValidationLab.XXXXX)
git clone https://github.com/devizer/NetCore.CaValidationLab
cd NetCore.CaValidationLab/CaValidationLab
time dotnet run -c Release
time dotnet publish -c Release --self-contained -o out -r $rid && out/CaValidationLab
rm -rf bin obj out
popd
