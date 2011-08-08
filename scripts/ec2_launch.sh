#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     ec2_launch.sh
# Purpose:  Launch an ec2 instance
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


#-------------------------------------------------------------------- process --
ec2_launch() {
  local FUNCTION="ec2_launch()"
  [ $# -ne 6 ] && fatal "${FUNCTION} This function requires six arguments."
  local AMI="$1"
  [ -z "${AMI}" ] && fatal "${FUNCTION} \$AMI is not defined"
  local INSTANCE_TYPE="$2"
  [ -z "${INSTANCE_TYPE}" ] && fatal "${FUNCTION} \$INSTANCE_TYPE is not defined"
  local KEYPAIR="$3"
  [ -z "${KEYPAIR}" ] && fatal "${FUNCTION} \$KEYPAIR is not defined"
  local GROUP="$4"
  [ -z "${GROUP}" ] && fatal "${FUNCTION} \$GROUP is not defined"
  local REGION="$5"
  [ -z "${REGION}" ] && fatal "${FUNCTION} \$REGION is not defined"
  local ZONE="$6"
  [ -z "${ZONE}" ] && fatal "${FUNCTION} \$ZONE is not defined"


  debug "${FUNCTION} $*"
  info "Launching instance of of ${AMI}"
  ec2-run-instances ${AMI} --instance-type "${INSTANCE_TYPE}" -k "${KEYPAIR}" -g "${GROUP}" --region "${REGION}" --availability-zone "${ZONE}" > ${TMP_FILE}
  RC=$?
  [ ${RC} -ne 0 ] && error "ec2-run-instances generated an error code [${RC}]"
  [ ! -z "${USE_DEBUG}" ] && cat ${TMP_FILE}
  local INSTANCE
  INSTANCE=`grep INSTANCE ${TMP_FILE} | awk '{print $2}'`
  info "New instance is ${INSTANCE}"
  local STATUS=""
  while [ "${STATUS}" != "running" ] 
  do
    sleep 10
    ec2-describe-instances ${INSTANCE} > ${TMP_FILE}
    [ ! -z "${USE_DEBUG}" ] && cat ${TMP_FILE}
    STATUS=`grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $6}'`
    info "${INSTANCE} status is ${STATUS}"
  done
  SERVER=`grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $4}'`
  info "Server is '${SERVER}'"


  NOW=`date +%y%m%d.%H%M`
  EPOCH=`date +%s`
  echo "${EPOCH}${SEP}${NOW}${SEP}${INSTANCE}${SEP}${AMI}${SEP}${SERVER}" >> ${LOG_DIR}/${SCRIPT_NAME}${DATA_EXT}

  return 0

}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env

  [ ! -f "${DEFAULT_CNF_FILE}" ] && error "Unable to locate default configuration '${DEFAULT_CNF_FILE}'"
  [ -z "${PARAM_INSTANCE_TYPE}" ]  && PARAM_INSTANCE_TYPE=`grep "^type" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_REGION}" ] && PARAM_REGION=`grep "^region" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_GROUP}" ] && PARAM_GROUP=`grep "^group" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_KEYPAIR}" ] && PARAM_KEYPAIR=`grep "^keypair" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_ZONE}" ] && PARAM_ZONE=`grep "^zone" ${DEFAULT_CNF_FILE} | cut -d= -f2`

  local CLONE_LOG="${LOG_DIR}/ec2_clone${DATA_EXT}"
  [ -f "${CLONE_LOG}" ] && LAST_AMI=`tail -1 ${CLONE_LOG} | awk -F${SEP} '{print $3}'`

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
  echo "Usage: ${SCRIPT_NAME}.sh -a <AMI> | -l [ -t instance-type | -r region | -k keypair | -g group | -z zone | -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    -a         AMI to launch"
  echo "    -l         Launch last cloned AMI"
  echo ""
  echo "  Optional:"
  echo "    -t         Type"
  echo "    -r         Region"
  echo "    -k         Keypair"
  echo "    -g         Group"
  echo "    -z         Availability Zone"
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
  while getopts a:r:g:t:k:z:lqv OPTION
  do
    case "$OPTION" in
      l)  PARAM_AMI=${LAST_AMI}; info "Using Last AMI '${LAST_AMI}'";;
      a)  PARAM_AMI=${OPTARG};;
      r)  PARAM_REGION=${OPTARG};;
      t)  PARAM_INSTANCE_TYPE=${OPTARG};;
      k)  PARAM_KEYPAIR=${OPTARG};;
      g)  PARAM_GROUP=${OPTARG};;
      z)  PARAM_ZONE=${OPTARG};;
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  [ -z "${PARAM_AMI}" ] && error "You must specify a AMI with -a. See --help for full instructions."
  [ -z "${PARAM_REGION}" ] && error "You must specify a region with -r. See --help for full instructions."
  [ -z "${PARAM_INSTANCE_TYPE}" ] && error "You must specify a instance type with -t. See --help for full instructions."
  [ -z "${PARAM_KEYPAIR}" ] && error "You must specify a keypair with -k. See --help for full instructions."
  [ -z "${PARAM_GROUP}" ] && error "You must specify a group with -g. See --help for full instructions."
  [ -z "${PARAM_ZONE}" ] && error "You must specify a zone with -z. See --help for full instructions."

  return 0
}

#----------------------------------------------------------------------- main --
# Main Script Processing
#
main () {
  [ ! -z "${TEST_FRAMEWORK}" ] && return 1
  bootstrap
  pre_processing
  process_args $*
  commence
  ec2_launch ${PARAM_AMI} ${PARAM_INSTANCE_TYPE} ${PARAM_KEYPAIR} ${PARAM_GROUP} ${PARAM_REGION} ${PARAM_ZONE}
  complete

  return 0
}

main $*
exit 0

# END
