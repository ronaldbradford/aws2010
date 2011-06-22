#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     aws_cost.sh
# Purpose:  Calculate AWS running cost
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.11 14-JUN-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#

ec2_cost() {
  FUNCTION="ec2_cost()"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts no arguments."
  [ -z "${EC2_INSTANCES}" ] && fatal "${FUNCTION} \$EC2_INSTANCES is not defined"
  [ ! -f "${EC2_INSTANCES}" ] && error "EC2 Server Index '${EC2_INSTANCES} does not exist"

  grep INSTANCE ${EC2_INSTANCES}  | grep running | awk -F'\t' '{print $10,$12,$22}' | sort | uniq -c > ${TMP_FILE}
  debug "Server counts"
  [ ! -z "${USE_DEBUG}" ] && cat ${TMP_FILE}
  GRAND_TOTAL=0
  SERVER_TOTAL=0
  info "Using current pricing in ${DEFAULT_CNF_FILE}"
  while read CNT TYPE ZONE SPOT
  do
    if [ -z "${SPOT}" ]
    then
      PRICE=`grep ${TYPE} ${DEFAULT_CNF_FILE} | grep "^ec2" | grep -v spot |  awk '{print $4}'`
    else
      PRICE=`grep ${TYPE} ${DEFAULT_CNF_FILE} | grep "^ec2" | grep spot |  awk '{print $4}'`
    fi
    if [ -z "${PRICE}" ]
    then
      warn "Unable to determine price for ${TYPE} ${ZONE} ${SPOT}"
    else
      TOTAL=`expr $CNT \* $PRICE`
      echo "$TOTAL,$CNT,$PRICE,$TYPE,$SPOT" >> ${DEFAULT_LOG_FILE}
      GRAND_TOTAL=`expr ${GRAND_TOTAL} + ${TOTAL}`
      SERVER_TOTAL=`expr ${SERVER_TOTAL} + ${CNT}`
    fi
  done < ${TMP_FILE}

  info "EC2 Instance breakdowns in '${DEFAULT_LOG_FILE}'"
  PRINT_TOTAL=`echo "${GRAND_TOTAL}" | awk '{printf "$%0.2f",$1/100.0}'`
  warn "Current hourly EC2 running cost = $PRINT_TOTAL for ${SERVER_TOTAL} servers"
  NOW=`date +%y%m%d.%H%M`
  EPOCH=`date +%s`
  echo "${EPOCH}${SEP}${NOW}${SEP}ec2${SEP}${GRAND_TOTAL}${SEP}${SERVER_TOTAL}" >> ${LOG_DIR}/${SCRIPT_NAME}${DATA_EXT}

  return 0
}

#-------------------------------------------------------------------- process --
process() {

  ec2_cost
  return 0

}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env
  EC2_INSTANCES="${CNF_DIR}/ec2${LOG_EXT}"
  SERVER_INDEX="${CNF_DIR}/servers${LOG_EXT}"

  return 0
}

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
  while getopts qv OPTION
  do
    case "$OPTION" in
      X)  EXAMPLE_ARG=${OPTARG};;
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  #[ -z "${EXAMPLE_ARG}" ] && error "You must specify a sample value for -X. See --help for full instructions."

  return 0
}

#----------------------------------------------------------------------- main --
# Main Script Processing
#
main () {
  [ ! -z "${TEST_FRAMEWORK}" ] && return 1
  bootstrap
  process_args $*
  pre_processing
  commence
  process
  complete

  return 0
}

main $*

# END
