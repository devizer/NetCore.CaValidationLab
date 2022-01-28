#!/usr/bin/env bash
set -e; set -u; set -o pipefail

Ldd_Version=$(cat ldd-version.log)
Gcc_Version=$(cat gcc-version.log)
Machine=$(cat machine.log)
Os=$(cat os.log)
Say "OS and Versions:
  Ldd_Version: [$Ldd_Version]
  Gcc_Version: [$Gcc_Version]
  Machine: [$Machine]
  Os: [$Os]"

Say "Provosioning in [$(pwd)]..."
sudo apt-get install sshpass rsync p7zip-full -y -qq >/dev/null
mkdir -p ~/.ssh; printf "Host *\n   StrictHostKeyChecking no\n   UserKnownHostsFile=/dev/null" > ~/.ssh/config


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
  tar cf - . | gzip -9     > "$tmp_archive/$name.tar.gz"
  build_all_known_hash_sums "$tmp_archive/$name.tar.gz"
  tar cf - . | xz -z -9 -e > "$tmp_archive/$name.tar.xz"
  build_all_known_hash_sums "$tmp_archive/$name.tar.xz"
  tar cf - . | bzip2 -z -9 > "$tmp_archive/$name.tar.bz2"
  build_all_known_hash_sums "$tmp_archive/$name.tar.bz2"
  7z a "$tmp_archive/$name.7z" * 
  build_all_known_hash_sums "$tmp_archive/$name.7z"
  
  echo "CONTENT of [$tmp_archive/$name.tar.gz]:"
  cd "$tmp_archive"
  tar tzvf "$name.tar.gz"
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
        Deploy-Set-of-Files "fio=$ver gcc=$Gcc_Version glib=$Ldd_Version is_shared=$is_shared mode=$mode machine=${Machine} os=${Os}" fio ../../libaio.so.1
      fi
    popd >/dev/null
  done
  popd >/dev/null
done
