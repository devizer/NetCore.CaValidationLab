#!/usr/bin/env bash
set -e; set -u; set -o pipefail


Ldd_Version=$(cat ldd-version.log)
Say "Ldd_Version: [$Ldd_Version]"
Gcc_Version=$(cat gcc-version.log)
Say "Gcc_Version: [$Gcc_Version]"

Machine=$(cat machine.log)
Say "Machine: [$Machine]"
Os=$(cat machine.log)
Say "Os: [$Os]"


function Get-Sub-Directories() {
  echo "$(find . -maxdepth 1 -type d | grep -v -E '^\.$' | sort -V)"
}

function Deploy-Set-of-Files() {
  local name="$1"
  shift
  # local tmp="$(mktemp -d -t "$name-XXXXXXXXXX")"
  local tmp="$(mktemp -d -t "fio-content-XXXXXXXXXX")"
  local tmp_archive="$(mktemp -d -t "fio-archive-XXXXXXXXXX")"
  local file;
  echo file list: [$*]
  for file in $*; do
    # echo " ... copying $file to $tmp/"
    cp -v "$file" "$tmp/"
  done
  pushd "$tmp" >/dev/null
  tar cf - . | gzip -9 > "$tmp_archive/$name.tar.gz"
  cd output
  echo "CONTENT of [$tmp_archive/$name.tar.gz]:"
  tar tzvf "$tmp_archive/$name.tar.gz"
  popd >/dev/null;
  rm -rf "$tmp" "$tmp_archive"
}

for dir_ver in $(Get-Sub-Directories "."); do
  ver="$(basename "$dir_ver")"
  Say "Version [$ver]"
  pushd "$dir_ver" >/dev/null
  for dir_mode in $(Get-Sub-Directories "."); do
    mode="$(basename "$dir_mode")"
    is_shared="False"; [[ "$mode" == *"shared"* ]] && is_shared="True";
    full_description="Version: [$ver]; ; Mode: [$mode]; Is Shared: [$is_shared]"
    echo "checking $full_description ..."
    pushd "$dir_mode" >/dev/null
      configure_result="$(cat configure.result)"
      make_result="$(cat make.result)"
      if [[ "$configure_result" -ne 0 ]]; then
        Say --Display-As=Error "Error configure.result is [$configure_result] for $full_description"
      elif [[ "$make_result" -ne 0 ]]; then
        Say --Display-As=Error "Error make.result is [$make_result] for $full_description"
      elif [[ ! -s fio ]]; then
        Say --Display-As=Error "Error missing fio for $full_description"
      else
        Say "Ready to Deploy the $full_description"
        for result in *.result; do
            echo "       $result: $(cat "$result")"
        done
        Say "Files: fio and ../../libaio.so.1"
        ls -la fio ../../libaio.so.1
        Deploy-Set-of-Files "fio-$ver gcc-$Gcc_Version glib-$Ldd_Version is_shared-$is_shared mode=$mode machine=${Machine} os=${Os}" fio ../../libaio.so.1
      fi
    popd >/dev/null
  done
  popd >/dev/null
done
