#!/usr/bin/env sh

# #############################################################################
# Simple way to use the library
# ============================================================================= 
#
# At any point in the script, we need to set the variable _LOG_LOGFILE using
# the function log::setLogFile "FILE_PATH"
# 
# Then using the following main functions:
# $ log::printVerbose "msg" 
# # Prints "msg" to STDERR only if the variable VERBOSE is set.
# 
# $ log::printInfo "msg"  
# # Prints "msg" in STDERR only if the variable VERBOSE is set. 
# # Writes "msg" in /log/dir/log_name.log only if _LOG_LOGFILE is 
#   declared and folder exists.
# 
# $ log::printError "msg" 
# # Prints "msg" in STDERR. 
# # Writes "msg" in /log/dir/log_name.err only if _LOG_LOGFILE is 
#   declared and folder exists.
# 
# $ log::exitError "msg"  
# # Prints "msg" in STDERR. 
# # Writes "msg" in /log/dir/log_name.log only if _LOG_LOGFILE is 
#   declared and folder exists. 
# # Exits with status 1
#
#
# #############################################################################

source datetime.sh

LOG_TYPE_INFO="INFO"
LOG_TYPE_ERROR="ERROR"
LOG_TYPE_WARNING="WARNING"
_LOG_LOGFILE=${_LOG_LOGFILE:-}  # Should be set with 'log::setLogFile' function.
LOG_LOG_EXT=".log"
LOG_ERR_EXT=".err"

# --------------------
# Wrappers of `echo`
# --------------------
log::printVerbose() {
  #   
  # Echoes input in stderr if in verbose mode.
  #
  [ -z "${VERBOSE:+x}" ] && return 0
  echo -e "$@" >&2
} && export -f log::printVerbose

log::printInfo() {
  #
  # Calls log::printVerbose because we don't want to display messages of type INFO 
  # by default, unless verbosity  VERBOSE is set.
  #
  log::printVerbose "$@"
  log::writeInfo "$@"
} && export -f log::printInfo

log::printWarning() {
  echo -e "WARNING: $@" >&2
  log::writeWarning "$@"
}

log::printDebug() {
  #
  # Echoes debugging input in stderr if in DEBUG set.
  # Sets the verbosity on.
  # Resets the verbosity if was off before.
  #
  [ -z "${DEBUG:+x}" ] && return 0
  [ -z "${VERBOSE:+x}" ] \
   || local _was_verbose=true
  VERBOSE=true
  log::printVerbose "DEBUG - $@" 
  [ -z "${_was_verbose:+x}" ] \
   && unset VERBOSE 
} && export -f log::printDebug

log::printError() {
  #   
  # Echoes input to stderr with error message.
  #
  echo -e "ERROR: $@" >&2
  log::writeError "$@"
} && export -f log::printError

log::exitError() {
  #   
  # log::printErrores the input and exits with error.
  #
  log::printError "$@"
  exit 1
} && export -f log::exitError


# -----------------
# Logging library
# -----------------
log::startLogging() {
  #
  # Initializes the logging in a file with the given :prefix: and :logdir:
  # 
  local prefix="${1:+$1}" logdir="${2:+$2}" withTime=${3:+true}
  mkdir -p "${logdir:+$logdir}"
  datetime::resetRunDatetime
  log::setLogFile "${logdir:+$logdir/}${withTime:+$(datetime::runDatetimeFileFormat)}${prefix}"
}

log::setLogFile() {
  #
  # Sets the log file. Checks the directory.
  #
  log::isLogValid "$1" \
   && export _LOG_LOGFILE="$1" \
   || return 1
  log::printInfo "Starting logging."
}

log::isLogValid() {
  #
  # Takes a file path and checks that:
  #  - it is defined
  #  - it's directory exists
  #
  local _log_file=$(readlink -f "$1" 2> /dev/null)
  [ -z "${_log_file:+x}" ] && log::printError  "Provide a valide path for the log file (given '$1')." && return 1 || true
  local _dirname=$(dirname "$_log_file")
  [ ! -d "$_dirname" ] && log::printError "${FUNCNAME} - Dirname '$_dirname' does not exist." && return 1 || true
}

log::isLogWritable() {
  #
  # Tells if a log can be written by checking if :
  #  - _LOG_LOGFILE is defined
  #  - _LOG_LOGFILE's dirname is a directory
  #
  [ ! -z "${_LOG_LOGFILE:+x}" ] \
   || return 1
  
  [ -d $(dirname "$_LOG_LOGFILE") ] \
   || return 1
}

log::write() {
  #
  # Writes message in a log file if it is possible.
  #
  log::isLogWritable || return 0
  ## Writes output
  local log_type="$1" && shift
  local log_file="$1" && shift
  echo -e "[$(datetime::logFormat)][$log_type][$BASHPID] $@" \
   >> "$log_file" \
   || echo "cannot write to $log_file" >&2
}

log::writeInfo() {
  #
  # Writes informative message in a log file.
  #
  log::write "$LOG_TYPE_INFO" "${_LOG_LOGFILE}${LOG_LOG_EXT}" "$@"
}

log::writeWarning() {
  #
  # Writes warning message in a log file.
  #
  log::write "$LOG_TYPE_WARNING" "${_LOG_LOGFILE}${LOG_LOG_EXT}" "$@"
}

log::writeError() {
  #
  # Writes error message in a log file.
  #
  log::write "$LOG_TYPE_ERROR" "${_LOG_LOGFILE}${LOG_ERR_EXT}" "$@"
}
