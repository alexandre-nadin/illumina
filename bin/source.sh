#!/usr/bin/env bash
_dir=$(readlink -f $(dirname "${BASH_SOURCE[0]}")) 
_basedir=$(dirname $_dir)

export PATH="${_dir}:${PATH}"

SUBMODULES=(slash cosr)

exportSubmodules() {
  local binpath
  for submodule in ${SUBMODULES[@]}; do 
    binpath="${_basedir}/${submodule}/bin"
    [ -d "$binpath" ] && export PATH="${binpath}":$PATH || :
  done
}

exportSubmodules
