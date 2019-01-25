#!/usr/bin/env bash
rid=linux-x64
if [[ $(uname -m) == armv7* ]]; then rid=linux-arm; fi; 
if [[ $(uname -m) == aarch64 ]]; then rid=linux-arm64; fi; 
echo Self-Contained rid is \[$rid\]

cd /tmp
cd $(mktemp -d)
git clone https://github.com/devizer/NetCore.CaValidationLab
cd NetCore.CaValidationLab/CaValidationLab
dotnet run
dotnet publish -c Release --self-contained -o out -r $rid
cd out
./CaValidationLab




