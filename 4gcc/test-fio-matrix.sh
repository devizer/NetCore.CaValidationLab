﻿
TOTAL_FAIL=0
function Run-4-Tests() {
  local i=0 image FAIL=0 job pids=() pid
  for image in "$@"; do
    let "i+=1"
    docker pull "$image" & 
    pid=$!
    pids[${#pids[@]}]=$pid
  done 
  
  for pid in "${pids[@]}"; do
      echo "wait for pid $pid"
      wait $pid || let "FAIL+=1"
  done

  let "TOTAL_FAIL+=FAIL"
  echo "Batch Errors: [$FAIL] Total Errors: [$TOTAL_FAIL]"
}

Run-4-Tests centos:6 centos:7 centos:8
Run-4-Tests debian:7 debian:8 debian:9 debian:10 debian:11
Run-4-Tests ubuntu:22.04 ubuntu:21.10 ubuntu:20.04 ubuntu:18.04
Run-4-Tests ubuntu:16.04 ubuntu:14.10 ubuntu:12.04

Run-4-Tests fedora:24 fedora:25 fedora:26 fedora:27 fedora:28
Run-4-Tests fedora:29 fedora:30 fedora:31 fedora:32 fedora:33
Run-4-Tests fedora:34 fedora:35 fedora:36

Run-4-Tests gentoo/stage3-amd64-nomultilib gentoo/stage3-amd64-hardened-nomultilib 
Run-4-Tests amazonlinux:1 amazonlinux:2 manjarolinux/base archlinux:base
Run-4-Tests opensuse/tumbleweed opensuse/leap:15 opensuse/leap:42




