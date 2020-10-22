#!/usr/bin/env bash
_dir=$(readlink -f $(dirname "${BASH_SOURCE[0]}")) 
_basedir=$(dirname $_dir)

popPaths()
{
  printf "${PATH}\n"              \
  | tr ':' '\n'                   \
  | grep -v "${_basedir}" \
  | tr '\n' ':' 
}

export PATH=$(popPaths)
