#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     ec2_clone.sh
# Purpose:  Clone an ec2 instance
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.10 09-JUN-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#
#CLONE_IDENTIFIER="-search"


#-------------------------------------------------------------------- process --
process() {
  local FUNCTION="process()"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function requires one argument."
  local INSTANCE="$1"
  [ -z "${INSTANCE}" ] && fatal "${FUNCTION} \$INSTANCE is not defined"

  local NOW=`date ${DATE_TIME_FORMAT}`
  local NAME="clone-${CLONE_IDENTIFIER}${NOW}"
  local DESCRIPTION="${SCRIPT_NAME}() ${INSTANCE} at ${NOW}"
  info "Generating Clone of ${INSTANCE} - ${NAME}"
  ec2-create-image ${INSTANCE} -d "${DESCRIPTION}" -n "${NAME}" > ${TMP_FILE}
  RC=$?
  [ ${RC} -ne 0 ] && error "ec2-create-image generated an error code [${RC}]"
  [ ! -z "${USE_DEBUG}" ] && cat ${TMP_FILE}
  local AMI
  AMI=`grep IMAGE ${TMP_FILE} | awk '{print $2}'`
  local STATUS=""
  while [ "${STATUS}" != "available" ] 
  do
    sleep 10
    ec2-describe-images ${AMI} > ${TMP_FILE}
    [ ! -z "${USE_DEBUG}" ] && cat ${TMP_FILE}
    STATUS=`grep IMAGE  ${TMP_FILE} | awk '{print $5}'`
    info "${AMI} status is ${STATUS}"
    SNAP=`grep BLOCKDEVICEMAPPING ${TMP_FILE} | awk '{print $3}'`
    [ ! -z "${SNAP}" ] && [ ! -z "${USE_DEBUG}" ] && ec2-describe-snapshots ${SNAP}
  done

  NOW=`date +%y%m%d.%H%M`
  EPOCH=`date +%s`
  echo "${EPOCH},${NOW},${AMI},${NAME},${INSTANCE}" >> ${LOG_DIR}/${SCRIPT_NAME}.csv

  return 0

}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env

  SERVER_INDEX="${CNF_DIR}/servers.txt"
  [ ! -f "${SERVER_INDEX}" ] && error "The required ${SERVER_INDEX} from aws_audit.sh does not exist"
  [ -z "${PARAM_INSTANCE}" ] && PARAM_INSTANCE=`tail -1 ${SERVER_INDEX} | awk '{print $2}'` && warn "Generated instance '${PARAM_INSTANCE}'"
  [ ! -z "${PARAM_INSTANCE}" ] && [ `grep ${PARAM_INSTANCE} ${SERVER_INDEX} | wc -l` -eq 0 ] && error "'${PARAM_INSTANCE}' not found in ${SERVER_INDEX}"

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
  echo "Usage: ${SCRIPT_NAME}.sh [ -i <ec2-instance> | -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    Nil"
  echo ""
  echo "  Optional:"
  echo "    -i         Instance to clone"
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
  while getopts i:qv OPTION
  do
    case "$OPTION" in
      i)  PARAM_INSTANCE=${OPTARG};;
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  # pre-processing will validate instance if specified

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
  process ${PARAM_INSTANCE}
  complete

  return 0
}

main $*

# END
