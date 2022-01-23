#!/usr/bin/env bash
set -o; set -u; set -o pipefail

Ldd_Version=$(cat ldd-version.log)
Say "Ldd_Version: [$Ldd_Version]"

for dir_ver in $(find . -maxdepth 1 -type d | grep -v -E '^\.$' | sort -V); do
  ver="$(basename "$dir_ver")"
  Say "Version [$ver]"
  pushd "$dir_ver"
  for dir_mode in $(find . -maxdepth 1 -type d | grep -v -E '^\.$' | sort -V); do
    mode="$(basename "$dirver")"
    is_shared="False"; [[ "$mode" == *"shared"* ]] && is_shared="True";
    Say "-- Version [$ver]; Mode [$mode]; Is Shared [$is_shared]"
    pushd "$dir_mode"
      configure_result="$(cat configure.result)"
      if [[ "$configure_result" -ne 0 ]]; then
        echo "   skip. configure.result is [$configure_result]"
      elif [[ ! -s fio ]]; then
        echo "   skip. missing fio"
      else
        Say "Ready to Deploy"
        for result in *.result; do
        echo "    $result: (cat "$result")"
        done
      fi
    popd
  done
  popd
done