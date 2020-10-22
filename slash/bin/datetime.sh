# bash

# -------------------
# Date-time library
# -------------------
datetime::datetime() {
  #
  # Prints the current date-time.
  #
  date +%y-%m-%d' '%H:%M:%S
}

datetime::resetRunDatetime() {
  #
  # (Re)Sets the script's starting date-time.
  #
  DATETIME_RUN_DATETIME=($(datetime::datetime))
}

datetime::initRunDatetime() {
  #
  # Sets the script's starting date-time is not already done.
  #
  [ -z "${DATETIME_RUN_DATETIME:+x}" ] \
   && datetime::resetRunDatetime
}

datetime::runDate() {
  #
  # Prints the script's starting date.
  #
  datetime::initRunDatetime
  echo "${DATETIME_RUN_DATETIME[0]}"  
}

datetime::runTime() {
  #
  # Prints the script's starting time.
  #   
  datetime::initRunDatetime
  echo "${DATETIME_RUN_DATETIME[1]}" 
}

datetime::runDatetime() {
  #
  # Prints the script's starting date-time
  #
  datetime::initRunDatetime
  echo "${DATETIME_RUN_DATETIME[@]}"
}

datetime::runDatetimeFileFormat() {
  #
  # Prints the script's starting date-time for file name.
  #
  datetime::initRunDatetime
  datetime::fileFormat "$(datetime::runDate)_$(datetime::runTime)"
}

datetime::fileFormat() {
  #
  # Prints the standard date-time formatted for file names
  #
  local dt="$(datetime::datetime)"
  [ ! -z "$1" ] && dt="$1"
  echo "$dt" \
   | sed -e 's| |_|g' \
         -e 's|:||g' \
         -e 's|-||g'
}

datetime::runDatetimeLogFormat() {
  #
  # Prints the script's starting date-time for logging.
  #
  datetime::initRunDatetime
  echo "$(datetime::runDate) $(datetime::runTime)"
}

datetime::logFormat() {
  #
  # Takes a date-time and formats it for file names
  # Takes standard date-time by default.
  #
  echo $(datetime::datetime) 
}
