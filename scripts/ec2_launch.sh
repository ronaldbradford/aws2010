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
SCRIPT_VERSION="0.12 08-NOV-2011"
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
  debug "${FUNCTION} $*"
  [ $# -lt 7 ] && fatal "${FUNCTION} This function requires seven/eight arguments."
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
  local COUNT="$7"
  [ -z "${COUNT}" ] && fatal "${FUNCTION} \$COUNT is not defined"
  local ELB="$8"
  [ -z "${ELB}" ] && warn "New instance(s) not being added to a load balancer"

  info "Launching instance of of ${AMI}"
  ec2-run-instances ${AMI} --instance-type "${INSTANCE_TYPE}" -k "${KEYPAIR}" -g "${GROUP}" --region "${REGION}" --availability-zone "${ZONE}"  -n ${COUNT} > ${TMP_FILE}
  local RC=$?
  debug_file "ec2-run-instances ${AMI} --instance-type ${INSTANCE_TYPE} ... -n ${COUNT}"
  [ ${RC} -ne 0 ] && error "ec2-run-instances generated an error code [${RC}]"

  INSTANCES=`grep INSTANCE ${TMP_FILE} | awk  -F'\t' '{print $2}'`
  info "New instance(s) is ${INSTANCES}"
  local STATUS=""
  while [ "${STATUS}" != "running" ] 
  do
    sleep ${LAUNCH_SLEEP_TIME} 
    ec2-describe-instances ${INSTANCES} > ${TMP_FILE}
    RC=$?
    STATUS=`grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $6}' | sort | uniq`
    info "${INSTANCES} status(es) is ${STATUS}"
  done
  debug_file "ec2-describe-instances ${INSTANCES} > ${TMP_FILE}"

  grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $2, $4}' > ${TMP_FILE}.list
  debug_file "grep INSTANCE" ${TMP_FILE}.list

  local INSTANCE
  local SERVER
  for INSTANCE in `echo $INSTANCES`
  do
    SERVER=`grep ${INSTANCE} ${TMP_FILE}.list | awk '{print $2}'`
    info "Server for '${INSTANCE}' is '${SERVER}'"
    [ ! -z "${SERVER}" ] && verify_ssh ${SERVER}
    RC=$?
    NOW=`date +%y%m%d.%H%M`
    EPOCH=`date +%s`
    echo "${EPOCH}${SEP}${NOW}${SEP}${INSTANCE}${SEP}${AMI}${SEP}${SERVER}" >> ${LOG_DIR}/${SCRIPT_NAME}${DATA_EXT}
    [ ! -z "${ELB}" ]  && register_with_elb ${ELB} ${INSTANCE}
  done 

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

  local AWS_COMMON_SCRIPT_FILE="${DIRNAME}/aws_common.sh"
  [ ! -f "${AWS_COMMON_SCRIPT_FILE}" ] && echo "ERROR: You must have a matching '${AWS_COMMON_SCRIPT_FILE}' with this script ${0}" && exit 1
  . ${AWS_COMMON_SCRIPT_FILE}

  return 0
}

#----------------------------------------------------------------------- help --
# Display Script help syntax
#
help() {
  echo ""
  echo "Usage: ${SCRIPT_NAME}.sh -a <AMI> | -c [ -t instance-type | -r region | -k keypair | -g group | -z zone | -l ELB | -n count | -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    -a         AMI to launch"
  echo "    -c         Launch last cloned AMI"
  echo ""
  echo "  Optional:"
  echo "    -g         Group"
  echo "    -k         Keypair"
  echo "    -l         Load Balancer"
  echo "    -n         Number of Servers"
  echo "    -r         Region"
  echo "    -t         Type"
  echo "    -z         Availability Zone"
  echo ""
  echo "    -q         Quiet Mode"
  echo "    -v         Verbose logging"
  echo "    --help     Script help"
  echo "    --version  Script version (${SCRIPT_VERSION}) ${SCRIPT_REVISION}"
  echo ""
  echo "  Dependencies:"
  echo "    common.sh"
  echo "    aws_common.sh"

  return 0
}

#-------------------------------------------------------------- process_args --
# Process Command Line Arguments
#
process_args() {
  FUNCTION="process_args()"
  debug "{$FUNCTION} ($*)"
  check_for_long_args $*

  PARAM_COUNT=1
  while getopts a:r:g:t:k:z:l:cn:qv OPTION
  do
    case "$OPTION" in
      c)  PARAM_AMI=${LAST_AMI}; info "Using Last AMI '${LAST_AMI}'";;
      a)  PARAM_AMI=${OPTARG};;
      r)  PARAM_REGION=${OPTARG};;
      t)  PARAM_INSTANCE_TYPE=${OPTARG};;
      k)  PARAM_KEYPAIR=${OPTARG};;
      g)  PARAM_GROUP=${OPTARG};;
      z)  PARAM_ZONE=${OPTARG};;
      n)  PARAM_COUNT=${OPTARG};;
      l)  PARAM_ELB=${OPTARG};;
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
  ec2_launch ${PARAM_AMI} ${PARAM_INSTANCE_TYPE} ${PARAM_KEYPAIR} ${PARAM_GROUP} ${PARAM_REGION} ${PARAM_ZONE} ${PARAM_COUNT} ${PARAM_ELB}
  complete

  return 0
}

main $*
exit 0

# END
