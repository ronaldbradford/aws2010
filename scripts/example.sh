#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     example.sh
# Purpose:  Example Shell Script with minimum requirements
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.10 DD-MMM-YYYY"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#

#-----------------------------------------------------------------  bootstrap --
# Essential script bootstrap
#
bootstrap() {
  local DIRNAME=`dirname $0`
  local COMMON_SCRIPT_FILE="${DIRNAME}/common.sh"
  [ ! -f "${COMMON_SCRIPT_FILE}" ] && echo "ERROR: You must have a matching '${COMMON_SCRIPT_FILE}' with this script ${0}" && exit 1
  . ${COMMON_SCRIPT_FILE}
  set_base_paths

  return 0
}

#----------------------------------------------------------------------- help --
# Display Script help syntax
#
help() {
  echo ""
  echo "Usage: ${SCRIPT_NAME}.sh -X <example-string> [ -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    -X         Example mandatory parameter"
  echo ""
  echo "  Optional:"
  echo "    -q         Quiet Mode"
  echo "    -v         Verbose logging"
  echo "    --help     Script help"
  echo "    --version  Script version (${SCRIPT_VERSION}) ${SCRIPT_REVISION}"
  echo ""
  echo "  Dependencies:"
  echo "    common.sh"

  return 0
}

#-------------------------------------------------------------- process_args --
# Process Command Line Arguments
#
process_args() {
  check_for_long_args $*
  debug "Processing supplied arguments '$*'"
  while getopts X:qv OPTION
  do
    case "$OPTION" in
      X)  EXAMPLE_ARG=${OPTARG};;
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  [ -z "${EXAMPLE_ARG}" ] && error "You must specify a sample value for -X. See --help for full instructions."

  return 0
}

#----------------------------------------------------------------------- main --
# Main Script Processing
#
main () {
  [ ! -z "${TEST_FRAMEWORK}" ] && return 1
  bootstrap
  process_args $*
  commence
  complete

  return 0
}

main $*

# END
