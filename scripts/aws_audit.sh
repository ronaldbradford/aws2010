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
  return 0
  local LB="N/A"
  info "Generating instance list. No Load Balancers found"
  for SERVER in `grep "^INSTANCE" ${EC2_INSTANCES} | grep running | awk '{print $2}'`
  do
    IP=`grep "${SERVER}" ${EC2_INSTANCES} | awk '{print $4,$15}'`
    debug "Got ${IP} for ${SERVER}"
    echo "${LB} ${SERVER} ${IP}" >> ${SERVER_INDEX}
  done

  return 0
}

#-------------------------------------------------------- determine_server_ip --
determine_server_ip() {
  local FUNCTION="determine_server_ip()"
  debug "${FUNCTION} $*"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function accepts one arguments."
  [ -z "${EC2_INSTANCES}" ] && fatal "${FUNCTION} \$EC2_INSTANCES is not defined"

  local LB=$1
  local LB_LOG="${CNF_DIR}/elb.${LB}${LOG_EXT}"
  #for SERVER in `grep InService ${LB_LOG} | awk '{print $2}'`
  local INSTANCE
  for INSTANCE in `cat ${LB_LOG} | awk '{print $2}'`
  do
    IP_DETAILS=`grep "${INSTANCE}" ${EC2_INSTANCES} |  grep INSTANCE | awk -F'\t' '{print $4,$18,$22}'`
    [ -z "${IP_DETAILS}" ] && warn "${INSTANCE} in '${LB}' not found in '${EC2_INSTANCES}'"
    debug "Got ${IP_DETAILS} for ${INSTANCE}"
    echo "${LB} ${INSTANCE} ${IP_DETAILS}" >> ${SERVER_INDEX}
  done

  return 0
}

#----------------------------------------------------------- pre_lb_instances --
# Expects ELB_INSTANCES 
per_elb_instances() {
  local FUNCTION="per_elb_instances()"
  debug "${FUNCTION} $*"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts zero arguments."
  [ -z "${ELB_INSTANCES}" ] && fatal "${FUNCTION} \$ELB_INSTANCES is not defined"

  local LB
  local LB_LOG
  local COUNT
  local IN_SERVICE
  local REMOVE_INSTANCES
  local RC
  for LB in `awk '{print $2}' ${ELB_INSTANCES}`
  do
    LB_LOG="${CNF_DIR}/elb.${LB}${LOG_EXT}"
    elb-describe-instance-health ${LB} > ${LB_LOG} 
    RC=$?
    debug_file "elb-describe-instance-health ${LB}"
    [ $RC -ne 0 ] && error "[${RC}] Unable to describe Load Balancer Instances"

    COUNT=`cat ${LB_LOG} | wc -l`
    IN_SERVICE=`grep InService ${LB_LOG} | wc -l`
    info "Generating revised instance list for load balancer '${LB}'. Has ${COUNT} servers, ${IN_SERVICE} InService"

    REMOVE_INSTANCES=`grep OutOfService ${LB_LOG} | awk '{printf("%s,",$2)}' | sed -e "s/,$//g"`
    #[ ! -z "${REMOVE_INSTANCES}" ] && warn "Removing Instances from ELB '${LB} for OutOfService '${REMOVE_INSTANCES}'"  && elb-deregister-instances-from-lb ${LB} --instances ${REMOVE_INSTANCES}

  done

  return 0
}


# Expects EC2_INSTANCES
not_elb_instances() {
  local FUNCTION="not_elb_instances()"
  debug "${FUNCTION} $*"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts zero arguments."
  [ -z "${EC2_INSTANCES}" ] && fatal "${FUNCTION} \$EC2_INSTANCES is not defined"

  cat ${CNF_DIR}/elb.*${LOG_EXT} | awk '{print $2}' > ${TMP_FILE}
  local MISSING_ELB_FILE="${LOG_DIR}/missing_elb${LOG_EXT}"
  local EC2_EXCLUDE_LIST="${CNF_DIR}/ec2.exclude.cnf"
  [ ! -f "${EC2_EXCLUDE_LIST}" ] && touch ${EC2_EXCLUDE_LIST}
  > ${MISSING_ELB_FILE}
  for INSTANCE in `grep INSTANCE ${EC2_INSTANCES} | grep running | awk '{print $2}'`
  do
    if [ `grep ${INSTANCE} ${TMP_FILE} | wc -l` -ne 1 ] 
    then
      [ `grep ${INSTANCE} ${EC2_EXCLUDE_LIST} | wc -l` -eq 1 ] && continue
      warn "$INSTANCE not in LB"
      echo "${INSTANCE}" >> ${MISSING_ELB_FILE}
    fi
  done

  COUNT=`cat ${MISSING_ELB_FILE} | wc -l`
  [ -s "${MISSING_ELB_FILE}" ]  &&  [ ! -z "${TO_EMAIL}" ]  &&   email "${DATE_TIME} '${COUNT}' instances missing from Load Balancers" "${TO_EMAIL}" ${MISSING_ELB_FILE}

  return 0
}

#---------------------------------------------------------- generate_elb_list --
# Expects ELB_INSTANCES
generate_elb_list() {
  local FUNCTION="generate_elb_list()"
  debug "${FUNCTION} $*"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts zero arguments."
  [ -z "${ELB_INSTANCES}" ] && fatal "${FUNCTION} \$ELB_INSTANCES is not defined"

  info "Generating list of Load Balancers (ELB) '${ELB_INSTANCES}'"
  elb-describe-lbs > ${TMP_FILE} 2>${TMP_FILE}.err
  local RC=$?
  debug_file "elb-describe-lbs"
  [ $RC -ne 0 ] && cat ${TMP_FILE}.err ${TMP_FILE} && error "[${RC}] Unable to describe Load Balancers"
  NO_ELB=`grep "No Load Balancers found" ${TMP_FILE} | wc -l`

  if [ ! -f "${ELB_INSTANCES}" ] 
  then
    mv ${TMP_FILE} ${ELB_INSTANCES} 
  else
    local DIFF
    DIFF=`diff ${ELB_INSTANCES} ${TMP_FILE} | wc -l`
    [ ${DIFF} -eq 0 ] && info "No new ELB found" 
    [ ${DIFF} -ne 0 ] && warn "Updating ELB List" && mv ${TMP_FILE} ${ELB_INSTANCES}
  fi

  if [ ${NO_ELB} -eq 1 ] 
  then
    no_elb_instances
  else
    per_elb_instances
    no_elb_instances
    not_elb_instances
  fi

  return 0
}

#---------------------------------------------------------- generate_elb_list --
# Expects EC2_INSTANCES
generate_ec2_list() {
  local FUNCTION="generate_elb_list()"
  debug "${FUNCTION} $*"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts zero arguments."
  [ -z "${EC2_INSTANCES}" ] && fatal "${FUNCTION} \$EC2_INSTANCES is not defined"

  info "Generating list of Instances  (EC2) '${EC2_INSTANCES}'"
  ec2-describe-instances > ${TMP_FILE} 2>${TMP_FILE}.err
  local RC=$?
  debug_file "ec2-describe-instances"
  [ $RC -ne 0 ] && cat ${TMP_FILE}.err ${TMP_FILE} && error "[${RC}] Unable to describe Instances"

  local DIFF
  DIFF=`diff ${EC2_INSTANCES} ${TMP_FILE} | wc -l`
  [ ${DIFF} -eq 0 ] && info "No change in EC2 instances detected, exiting nicely" && return 1
  warn "Change in EC2 instances detected"
  mv ${TMP_FILE} ${EC2_INSTANCES}

  return 0
}

#------------------------------------------------------ generate_server_index --
# Expects ELB_INSTANCES, SERVER_INDEX
generate_server_index() {
  local FUNCTION="generate_server_index()"
  debug "${FUNCTION} $*"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts zero arguments."
  [ -z "${ELB_INSTANCES}" ] && fatal "${FUNCTION} \$ELB_INSTANCES is not defined"
  [ -z "${SERVER_INDEX}" ] && fatal "${FUNCTION} \$SERVER_INDEX is not defined"

  local LB
  > ${SERVER_INDEX}
  for LB in `awk '{print $2}' ${ELB_INSTANCES}`
  do
    determine_server_ip ${LB} 
  done

  SERVER_COUNT=`cat ${SERVER_INDEX} | wc -l`
  info "Generating ELB/EC2/IP cross reference '${SERVER_INDEX}' for ${SERVER_COUNT} servers"
  info "Generating host index for parrallel processing '${HOST_INDEX}'"
  awk '{print $4}' ${SERVER_INDEX} > ${HOST_INDEX}

  return 0
}

#-------------------------------------------------------------------- process --
process() {
  local FUNCTION="process()"
  debug "${FUNCTION} $*"

  generate_ec2_list
  local RC=$?
  [ $RC -eq 1 ] && return 0  # Clean exit
  generate_elb_list


  generate_server_index

  CFG_SERVER_INDEX="${CNF_DIR}/servers${LOG_EXT}"
  ${SCRIPT_DIR}/detect_spot_change.sh -n ${SERVER_INDEX} & 
  # Give script time to get current config before it is overritten next step
  sleep 15
  cp ${SERVER_INDEX} ${CFG_SERVER_INDEX}

  return 0
}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env

  ELB_INSTANCES="${CNF_DIR}/elb${LOG_EXT}"
  EC2_INSTANCES="${CNF_DIR}/ec2${LOG_EXT}"
  [ -f "${DEFAULT_CNF_FILE}" ] && TO_EMAIL=`grep "^email" ${DEFAULT_CNF_FILE} | cut -d= -f2`

  SERVER_INDEX="${LOG_DIR}/servers.${DATE_TIME}${LOG_EXT}"
  HOST_INDEX="${CNF_DIR}/hosts${LOG_EXT}"

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
  echo "Usage: ${SCRIPT_NAME}.sh [ -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
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
