#!/usr/bin/env bash
_dir=$(readlink -f $(dirname "${BASH_SOURCE[0]}")) 
_basedir=$(dirname $_dir)

popPaths()
{
  printf "${PATH}"        \
  | tr ':' '\n'           \
  | grep -v "${_basedir}" \
  | tr '\n' ':'           \
  | sed 's/:$//'
}

export PATH=$(popPaths)
