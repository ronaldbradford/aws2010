#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     ec2_spot_launch.sh
# Purpose:  Launch an ec2 spot instance
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.11 04-AUG-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#


#-------------------------------------------------------------------- process --
ec2_spot_launch() {
  local FUNCTION="ec2_spot_launch()"
  [ $# -ne 9 ] && fatal "${FUNCTION} This function requires at least five arguments."
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
  local PRICE="$7"
  [ -z "${PRICE}" ] && fatal "${FUNCTION} \$PRICE is not defined"
  local NUMBER="$8"
  [ -z "${NUMBER}" ] && fatal "${FUNCTION} \$NUMBER is not defined"
  local SPOT_TYPE="$9"
  [ -z "${SPOT_TYPE}" ] && fatal "${FUNCTION} \$SPOT_TYPE is not defined"


  debug "${FUNCTION} $*"
  debug "${FUNCTION} TMP_FILE=${TMP_FILE}"
  info "Launching ${NUMBER} ${SPOT_TYPE} instance(s)  (Max Price=${PRICE}) of ${AMI}"
  ec2-request-spot-instances ${AMI} --instance-type "${INSTANCE_TYPE}" -k "${KEYPAIR}" -g "${GROUP}" --region "${REGION}" --availability-zone "${ZONE}" -p ${PRICE} -n ${NUMBER} --type ${SPOT_TYPE}  > ${TMP_FILE}
  RC=$?
  debug_file "ec2-request-spot-instances ${AMI} --instance-type ${INSTANCE_TYPE}"
  [ ${RC} -ne 0 ] && error "ec2-request-spot-instances generated an error code [${RC}]"

  local SPOTS
  SPOTS=`awk -F'\t' '{print $2}' ${TMP_FILE}`
  info "SPOT Instance reservations are '${SPOTS}'"

  local INSTANCES
  while [ -z "${INSTANCES}" ] 
  do
    sleep 10
    ec2-describe-spot-instance-requests ${SPOTS} > ${TMP_FILE}
    NEW_INSTANCES=`awk -F'\t' '{print $12}' ${TMP_FILE}`
    COUNT_INSTANCES=`echo ${NEW_INSTANCES} | awk '{print NF}'`
    info "${COUNT_INSTANCES} SPOT Instance ids are '${NEW_INSTANCES}'"
    [ ${COUNT_INSTANCES} -eq ${NUMBER} ] && INSTANCES=${NEW_INSTANCES}
  done

  
  local STATUS=""
  while [ "${STATUS}" != "running" ] 
  do
    sleep 10
    ec2-describe-instances ${INSTANCES} > ${TMP_FILE}
    RC=$?

    STATUS=`grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $6}' | sort | uniq`
    info "${INSTANCES} statuses are ${STATUS}"
  done
  debug_file "ec2-describe-instances ${INSTANCES}"
  SERVER=`grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $4}'`
  info "Instance CSV List is "`echo ${INSTANCES} | sed -e "s/ /,/g"`
  info "Server List is '${SERVER}'"


  NOW=`date +%y%m%d.%H%M`
  EPOCH=`date +%s`
  grep INSTANCE  ${TMP_FILE} | awk  -F'\t' '{print $2, $4}' > ${TMP_FILE}
  while read INSTANCE SERVER 
  do
    echo "${EPOCH}${SEP}${NOW}${SEP}${INSTANCE}${SEP}${AMI}${SEP}${SERVER}" >> ${LOG_DIR}/${SCRIPT_NAME}${DATA_EXT}
  done < ${TMP_FILE}

  return 0

}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env

  [ ! -f "${DEFAULT_CNF_FILE}" ] && error "Unable to locate default configuration '${DEFAULT_CNF_FILE}'"
  info "Using default options from '${DEFAULT_CNF_FILE}'"
  [ -z "${PARAM_INSTANCE_TYPE}" ]  && PARAM_INSTANCE_TYPE=`grep "^type" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_REGION}" ] && PARAM_REGION=`grep "^region" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_GROUP}" ] && PARAM_GROUP=`grep "^group" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_KEYPAIR}" ] && PARAM_KEYPAIR=`grep "^keypair" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_ZONE}" ] && PARAM_ZONE=`grep "^zone" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_PRICE}" ] && PARAM_PRICE=`grep "^price" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_NUMBER}" ] && PARAM_NUMBER=`grep "^number" ${DEFAULT_CNF_FILE} | cut -d= -f2`
  [ -z "${PARAM_SPOT_TYPE}" ] && PARAM_SPOT_TYPE=`grep "^spottype" ${DEFAULT_CNF_FILE} | cut -d= -f2`

  CLONE_LOG="${LOG_DIR}/ec2_clone${DATA_EXT}"
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
  echo "Usage: ${SCRIPT_NAME}.sh -a <AMI> | -c [ -t instance-type | -r region | -k keypair | -g group | -z zone  | -p price | -n number | -s spottype | -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    -a         AMI to launch"
  echo ""
  echo "  Optional:"
  echo "    -c         Launch last cloned AMI"
  echo "    -t         Type"
  echo "    -r         Region"
  echo "    -k         Keypair"
  echo "    -g         Group"
  echo "    -z         Availability Zone"
  echo "    -p         Max Spot Price"
  echo "    -n         Number of Instances"
  echo "    -s         Spot Type"
  echo ""
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
  while getopts a:r:g:t:k:z:p:n:s:cqv OPTION
  do
    case "$OPTION" in
      c)  PARAM_AMI=${LAST_AMI}; info "Using last recorded cloned AMI ${LAST_AMI}";;
      a)  PARAM_AMI=${OPTARG};;
      r)  PARAM_REGION=${OPTARG};;
      t)  PARAM_INSTANCE_TYPE=${OPTARG};;
      k)  PARAM_KEYPAIR=${OPTARG};;
      g)  PARAM_GROUP=${OPTARG};;
      z)  PARAM_ZONE=${OPTARG};;
      p)  PARAM_PRICE=${OPTARG};;
      n)  PARAM_NUMBER=${OPTARG};;
      s)  PARAM_SPOT_TYPE=${OPTARG};;
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
  [ -z "${PARAM_PRICE}" ] && error "You must specify a price with -p. See --help for full instructions."
  [ -z "${PARAM_NUMBER}" ] && error "You must specify a number of instances with -n. See --help for full instructions."
  [ -z "${PARAM_SPOT_TYPE}" ] && error "You must specify a spot type with -s. See --help for full instructions."

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
  ec2_spot_launch ${PARAM_AMI} ${PARAM_INSTANCE_TYPE} ${PARAM_KEYPAIR} ${PARAM_GROUP} ${PARAM_REGION} ${PARAM_ZONE} ${PARAM_PRICE} ${PARAM_NUMBER} ${PARAM_SPOT_TYPE}
  complete

  return 0
}

main $*
exit 0

# END
