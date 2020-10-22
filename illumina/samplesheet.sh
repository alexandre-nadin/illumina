#!/usr/bin/env bash
#
# This library is designed to help manipulate illumina samplesheets.
# Ideally every implementations drafted here should be later implemented
# in the python project illumina-helper.
#
source log.sh

SSHEET_CURL_NB_TRIES=3
SSHEET_CURL_RETRY_DELAY=1
SSHEET_CURL_RETRY_MAX_TIMES=5

SSHEET_WITH_TAGS=false
SSHEET_PROJECT_TAG="Project_"
SSHEET_SAMPLE_TAG="Sample_"
SSHEET_FILENAME="samplesheet.csv"
SSHEET_DELIMITER=","
SSHEET_PROJECT_START_REGEX="\(^\|${SSHEET_DELIMITER}\)"
SSHEET_PROJECT_END_REGEX="\(${SSHEET_DELIMITER}\|\$\)"

SSHEET_SAMPLE_ID_REGEX="Sample.*ID"
SSHEET_SAMPLE_NAME_REGEX="Sample.*Name"
SSHEET_PROJECT_NAME_REGEX="Sample.*Project"
SSHEET_DATA_HEADER_REGEX='\[Data\]'

# -----------
# Structure
# -----------
ssheet::sampleTagStructed() {
  $SSHEET_WITH_TAGS && printf "${SSHEET_SAMPLE_TAG}" || printf ""
}  

ssheet::projectTagStructed() {
  $SSHEET_WITH_TAGS && printf "${SSHEET_PROJECT_TAG}" || printf ""
}  

ssheet::removeTag() {
  sed -e "s/^${1}//" \
   < /dev/stdin
}

ssheet::removeProjectTag() {
   ssheet::removeTag "$(ssheet::projectTagStructed)" \
   < /dev/stdin
}
ssheet::projectRegex() {
  printf "${SSHEET_PROJECT_START_REGEX}"
  ssheet::projectTagStructed
  printf "${1}${SSHEET_PROJECT_END_REGEX}"
}

ssheet::noEmptyLine() {
  sed '/^$/d' < /dev/stdin
}

ssheet::2unix() {
  tr '\r' '\n' < /dev/stdin
}

ssheet::rmSpaces() {
  sed 's/[[:space:]]//g' < /dev/stdin
}

ssheet::build() {
  ssheet::fetch "$1"     \
   | ssheet::2unix       \
   | ssheet::noEmptyLine \
   | ssheet::noSpaces
}

ssheet::noSpaces() {
  local ssheet=$(cat /dev/stdin)
  ssheet::metadata    <<< "$ssheet"
  ssheet::data <<< "$ssheet" \
   | ssheet::rmSpaces
}

ssheet::tagData() {
  local ssheet=$(cat /dev/stdin)
  ssheet::metadata    <<< "$ssheet"
  ssheet::dataHeader  <<< "$ssheet"
  ssheet::data        <<< "$ssheet" \
   | ssheet::addDataTags

}

ssheet::addDataTags() {
  #
  # Takes sample sheet data and formats samples
  # Careful, the header should be included.
  #
  local ssheet="$(cat /dev/stdin)"
  colSampleId=$(ssheet::dataColumnIndex "$SSHEET_SAMPLE_ID_REGEX" <<< "$ssheet")
  colSampleName=$(ssheet::dataColumnIndex "$SSHEET_SAMPLE_NAME_REGEX" <<< "$ssheet")
  colPrjName=$(ssheet::dataColumnIndex "$SSHEET_PROJECT_NAME_REGEX" <<< "$ssheet")
  awk -F"$SSHEET_DELIMITER" \
    '{
        OFS=FS;
        $'"$colSampleId"'= "'"${SSHEET_SAMPLE_TAG}"'" $'"$colSampleName"'; 
        $'"$colPrjName"'= "'"${SSHEET_PROJECT_TAG}"'" $'"$colPrjName"'; 
        print $0 
      }'                     \
   < <(ssheet::dataSamples <<< "$ssheet")
}


ssheet::projectFiltered() {
  #
  # Reads a sample sheet content and builds another one from it for the specified project.
  #
  local ssheet=$(cat /dev/stdin)
  local prj="$1"
  ssheet::metadata   <<< "$ssheet"
  ssheet::dataHeader <<< "$ssheet"
  ssheet::data       <<< "$ssheet" \
   | ssheet::filterProject "$prj"
} 

ssheet::filterProject() {
  #
  # Takes a samplesheet's data and filters the lines with the given project name.
  #
  local prj="$1"
  grep -- $(ssheet::projectRegex ${prj}) \
   < /dev/stdin                        \
    || log::printError "Could not find project '$prj' in samplesheet."
}


# -----------------------
# Fetching Sample Sheet
# -----------------------
ssheet::fetch() {
  #
  # Fetches the given sample sheet either as a remote or local file.
  #
  local ssheet="$1"
  if ssheet::isRemote "$ssheet"; then
    ssheet::download "$ssheet" \
     || log::exitError "Couldn't download sample sheet '$ssheet'."
  else
    ssheet::readLocal "$ssheet" \
     || log::exitError "Sample sheet '$ssheet' is not a local file."
  fi
}

ssheet::isRemote() {
  #
  # Checks if given file is remote from IP or https.
  #
  local remote_regex="(^\b([0-9]{1,3}\.){3}[0-9]{1,3}\b)|(^https?://)"
  grep -qE "$remote_regex" <<< "$1" \
   && return 0 \
   || return 1
}

ssheet::readLocal() {
  local ssheet="$1"
  [ -f "$ssheet" ] || return 1
  local ssheet="$ssheet"
  log::printInfo "Reading local sample sheet '$ssheet'"
  cat "$ssheet"
}

ssheet::download() {
  local ssheet="$1"
  log::printInfo "Downloading sample sheet:\n$(ssheet::downloadCmd $ssheet)"
  ssheet::downloadCmdExec "$ssheet"
}

ssheet::downloadCmdExec() {
  eval "$(ssheet::downloadCmd $@)"
}

ssheet::downloadCmd() {
  local ssheet="$1"
  cat << eol
  curl -f -s "$ssheet" \
   --retry $SSHEET_CURL_NB_TRIES \
   --retry-delay $SSHEET_CURL_RETRY_DELAY \
   --retry-max-time $SSHEET_CURL_RETRY_MAX_TIMES
eol
}

# ---------------------------
# Sample Sheet Manipulation
# ---------------------------
ssheet::headerLine() {
  #
  # Returns the line of the samplesheet's data header.
  #
  cat /dev/stdin \
   | grep -n "$SSHEET_DATA_HEADER_REGEX" \
   | awk -F':' '{print $1}'
}

ssheet::metadata() {
  #
  # Outputs the metadata from the given sample sheet file.
  #
  local ssheet="$(cat /dev/stdin)"
  head -n $(ssheet::headerLine <<< "$ssheet") \
   <<< "$ssheet"
}

ssheet::data() {
  #
  # Outputs the data from the given sample sheet file. 
  #
  local ssheet="$(cat /dev/stdin)"
  tail -n +$(( $(ssheet::headerLine <<< "$ssheet") +1 )) \
    <<< "$ssheet" 
}

ssheet::hasData() {
  if [ $(ssheet::dataSamples < /dev/stdin | wc -l) -ge 1 ]; then
    return 0
  else
    return 1
  fi
}

ssheet::dataHeader() {
  #
  # Outputs the data header from the given sample sheet file. 
  #
  cat /dev/stdin  \
   | ssheet::data \
   | head -n 1
}

ssheet::dataSamples() {
  #
  # Outputs the data samples from the given sample sheet file. 
  #
  cat /dev/stdin  \
   | ssheet::data \
   | tail -n +2
}

ssheet::dataColumnIndex() {
  #
  # Gets a samplesheet and a column name.
  # Returns the index of the column name.
  #
  local colNamePattern="$1"
  cat /dev/stdin              \
   | csv.get-col-names        \
      -d "$SSHEET_DELIMITER" \
      --output-delimiter '\n' \
      --count                 \
      --after-counter '\t'    \
   | grep "$colNamePattern"   \
   | awk -F'\t' '{print $1}'
}

ssheet::projects() {
  #
  # Takes a sample sheet and returns all projects found in it.
  #
  local ssheet="$(cat /dev/stdin)"
  local colidx_prj=$(
    ssheet::data <<< "$ssheet"    \
     | ssheet::dataColumnIndex "$SSHEET_PROJECT_NAME_REGEX"
  )
  ssheet::dataSamples <<< "$ssheet" \
   | awk -F"$SSHEET_DELIMITER"     \
       '{print $'"$colidx_prj"'}'   \
   | ssheet::removeProjectTag       \
   | sort                           \
   | uniq
}
