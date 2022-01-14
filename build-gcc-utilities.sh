#!/usr/bin/env bash

function generate_uninstall_this_gcc() {
  file="$1"
  to="$2"
  printf '#!/usr/bin/env bash
      [[ "$1" == "--verbose" ]] && Is_Verbose=true;
      pushd "$(dirname "$0")" > /dev/null; ScriptPath="$(pwd)"; popd > /dev/null
      pushd "$ScriptPath" >/dev/null
      # it iss an output of tar cf gcc.tar.xz
      Files='"'"> "$to"

  cat "$file" | gzip -f -d | tar tf - | while IFS= read -r line; do
    # if 0 || [[ "${line: -1}" != "/" ]] && [[ "${line}" != "./man" ]]; then
      # echo 'test -f "'$line'" && (rm -f "'$line'" || sudo rm -f "'$line'" 2>/dev/null)' >> "$to"
      echo $line >> "$to"
    # fi
  done

cat <<-'EOF' >> "$to"
'
    for file in $Files; do
      if [[ -L "$file" ]]; then
        if [[ -f "$(readlink -f "$file")" ]]; then 
          [[ "$Is_Verbose" == true ]] && echo "deleting a link to a file: [$file]"; 
          rm -f "$file";
        fi
      fi
    done
    for file in $Files; do
      if [[ -f "$file" ]]; then
        [[ "$Is_Verbose" == true ]] && echo "deleting a regular file: [$file]"; 
        rm -f "$file"
      fi
    done

    popd >/dev/null
EOF

chmod +x "$to"
}

function _ignore_a_local_test_ () {
tar xzf 1.tar.gz
generate_uninstall_this_gcc 1.tar.gz uninstall-this-gcc.sh
./uninstall-this-gcc.sh --verbose | tee uninstall.log
nano uninstall.log
}


function build_all_known_hash_sums() {
  local file="$1"
  for alg in md5 sha1 sha224 sha256 sha384 sha512; do
    if [[ "$(command -v ${alg}sum)" != "" ]]; then
      local sum=$(eval ${alg}sum $1 | awk '{print $1}')
      printf "$sum" > "$1.${alg}"
    else
      echo "warning! ${alg}sum missing"
    fi
  done
}
