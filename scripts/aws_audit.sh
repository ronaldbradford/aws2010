#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     aws_audit.sh
# Purpose:  AWS Audit of EC2/ELB Instances
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.10 08-JUN-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#


#----------------------------------------------------------- no_elb_instances --
no_elb_instances() {
  local LB="N/A"
  info "Generating instance list. No Load Balancers found"
  for SERVER in `grep "^INSTANCE" ${EC2_INSTANCES} | awk '{print $2}'`
  do
    IP=`grep "${SERVER}" ${EC2_INSTANCES} | awk '{print $4,$15}'`
    debug "Got ${IP} for ${SERVER}"
    echo "${LB} ${SERVER} ${IP}" >> ${SERVER_INDEX}
  done

  return 0
}

#-------------------------------------------------------- determine_server_ip --
determine_server_ip() {
  local LB=$1
  local LB_LIST=$2

  for SERVER in `awk '{print $2}' ${LB_LIST}`
  do
    IP=`grep "${SERVER}" ${EC2_INSTANCES} | awk '{print $4,$15}'`
    debug "Got ${IP} for ${SERVER}"
    echo "${LB} ${SERVER} ${IP}" >> ${SERVER_INDEX}
  done

  return 0
}

#----------------------------------------------------------- pre_lb_instances --
per_elb_instances() {
  for LB in `awk '{print $2}' ${ELB_INSTANCES}`
  do
    LB_LOG="${CNF_DIR}/elb.${LB}${LOG_EXT}"
    elb-describe-instance-health ${LB} > ${LB_LOG} 
    RC=$?
    [ $RC -ne 0 ] && error "[${RC}] Unable to describe Load Balancer Instances"
    COUNT=`cat ${LB_LOG} | wc -l`
    info "Generating instance list for load balancer '${LB}'. Has ${COUNT} servers"
    determine_server_ip ${LB} ${LB_LOG}
  done
  return 0
}


not_elb_instances() {
  cat ${CNF_DIR}/elb.*${LOG_EXT} | awk '{print $2}' > ${TMP_FILE}
  for INSTANCE in `grep INSTANCE ${EC2_INSTANCES} | grep running | grep c1.medium | awk '{print $2}'`
  do
    [ `grep ${INSTANCE} ${TMP_FILE} | wc -l` -ne 1 ] && warn "$INSTANCE not in LB"
  done

  return 0
}

#-------------------------------------------------------------------- process --
process() {
  info "Generating List of Load Balancers (ELB) '${ELB_INSTANCES}'"


  elb-describe-lbs > ${ELB_INSTANCES} 2>${TMP_FILE}
  RC=$?
  NO_ELB=`grep "No LoadBalancers found" ${ELB_INSTANCES} | wc -l`
  [ $RC -ne 0 ] && cat ${TMP_FILE} && error "[${RC}] Unable to describe Load Balancers"
  info "Generating list of Instances  (EC2) '${EC2_INSTANCES}"
  ec2-describe-instances > ${EC2_INSTANCES} 2>${TMP_FILE}
  RC=$?
  [ $RC -ne 0 ] && cat ${TMP_FILE} && error "[${RC}] Unable to describe Instances"

  if [ ${NO_ELB} -eq 1 ] 
  then
    no_elb_instances
  else
    per_elb_instances
    no_elb_instances
    not_elb_instances
  fi
  SERVER_COUNT=`cat ${SERVER_INDEX} | wc -l`
  info "Generating ELB/EC2/IP cross reference '${SERVER_INDEX}' for ${SERVER_COUNT} servers"
  awk '{print $4}' ${SERVER_INDEX} > ${HOST_INDEX}

  return 0

}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env

  ELB_INSTANCES="${CNF_DIR}/elb${LOG_EXT}"
  EC2_INSTANCES="${CNF_DIR}/ec2${LOG_EXT}"
  SERVER_INDEX="${CNF_DIR}/servers${LOG_EXT}"
  HOST_INDEX="${CNF_DIR}/hosts${LOG_EXT}"

  > ${SERVER_INDEX}
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
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  [ $# -gt 0 ] && error "${SCRIPT_NAME} does not accept any arguments"

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
