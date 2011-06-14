#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     ec2_spot_history.sh
# Purpose:  Get current ec2 spot history
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.10 14-JUN-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#


#-------------------------------------------------------------------- process --
process() {
  local FUNCTION="process()"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function requires one argument."
  local INSTANCE_TYPE="$1"
  [ -z "${INSTANCE_TYPE}" ] && fatal "${FUNCTION} \$INSTANCE_TYPE is not defined"

  LOG_FILE=${CNF_DIR}/${SCRIPT_NAME}.${INSTANCE_TYPE}.tsv

  if [ ! -f "${LOG_FILE}" ] 
  then
    warn "No current Information recorded for '${INSTANCE_TYPE}'"
    SINCE=""
  else
    LAST_DT=`tail -1 ${LOG_FILE} | awk '{print $3}'`
    SINCE="-s ${LAST_DT}"
  fi

  info "Getting spot instance history for '${INSTANCE_TYPE}' since '${LAST_DT}'"

  ec2-describe-spot-price-history -t ${INSTANCE_TYPE} -d "Linux/UNIX" ${SINCE} > ${TMP_FILE}
  COUNT=`cat ${TMP_FILE} | grep -v ${LAST_DT} | wc -l`
  info "Have '${COUNT}' new spot prices"

  COST=`tail -1 ${TMP_FILE} | awk '{print $2 * 100.0}'`
  DT=`tail -1 ${TMP_FILE} | awk '{print $3}'`

  info "Current cost for '${INSTANCE_TYPE} is '${COST}' at '${DT}'"

  NOW=`date +%y%m%d.%H%M`
  EPOCH=`date +%s`
  echo "${EPOCH},${NOW},${INSTANCE_TYPE},${COST},${DT}" >>  ${LOG_DIR}/${SCRIPT_NAME}.log

  [ ! -f "${LOG_FILE}" ] && cp ${TMP_FILE} ${LOG_FILE} && return 0
  [ ${COUNT} -gt 0 ] && cat ${TMP_FILE} | grep -v "${LAST_DT}" >> ${LOG_FILE}



  return 0

}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env
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
  echo "Usage: ${SCRIPT_NAME}.sh -i <ec2-instance> [ -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    -i         Instance to clone"
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
  while getopts t:qv OPTION
  do
    case "$OPTION" in
      t)  PARAM_TYPE=${OPTARG};;
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  [ -z "${PARAM_TYPE}" ] && error "You must specify an instance type for -t. See --help for full instructions."

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
  process ${PARAM_TYPE}
  complete

  return 0
}

main $*

# END
