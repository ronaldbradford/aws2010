#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     elb_move.sh
# Purpose:  Move Instances between load balances
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.10 05-AUG-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#


#-------------------------------------------------------- deregister_with_elb --
deregister_with_elb() {
  local FUNCTION="deregister_with_elb()"
  [ $# -ne 2 ] && fatal "${FUNCTION} This function requires two arguments."
  local ELB="$1"
  [ -z "${ELB}" ] && fatal "${FUNCTION} \$ELB is not defined"
  local INSTANCE="$2"
  [ -z "${INSTANCE}" ] && fatal "${FUNCTION} \$INSTANCE is not defined"

  info "Removing Instance(s) '${INSTANCE}' from Load Balancer '${ELB}'"

  elb-deregister-instances-from-lb ${ELB} --instances ${INSTANCE} > ${TMP_FILE}
  RC=$?
  [ ${RC} -ne 0 ] && warn "Unable to de-register with Load Balancer"`cat ${TMP_FILE}` 
  REMOVED=`grep ${INSTANCE} ${TMP_FILE} | wc -l`
  [ ${REMOVED} -ne 0 ] && warn "'${INSTANCE}' still registered with '${ELB}'"

  return 0
}
#---------------------------------------------------------- register_with_elb --
register_with_elb() {
  local FUNCTION="register_with_elb()"
  [ $# -ne 2 ] && fatal "${FUNCTION} This function requires two arguments."
  local ELB="$1"
  [ -z "${ELB}" ] && fatal "${FUNCTION} \$ELB is not defined"
  local INSTANCE="$2"
  [ -z "${INSTANCE}" ] && fatal "${FUNCTION} \$INSTANCE is not defined"

  info "Adding Instance '${INSTANCE}' to Load Balancer '${ELB}'"

  elb-register-instances-with-lb ${ELB} --instances ${INSTANCE} > ${TMP_FILE}
  RC=$?
  [ ${RC} -ne 0 ] && warn "Unable to register with Load Balancer"`cat ${TMP_FILE}` 
  ADDED=`grep ${INSTANCE} ${TMP_FILE} | wc -l`
  [ ${ADDED} -ne 1 ] && warn "'${INSTANCE}' not registered with '${ELB}'"

  return 0
}

#-------------------------------------------------------------------- process --
process() {
  local FUNCTION="process()"
  [ $# -ne 4 ] && fatal "${FUNCTION} This function requires three arguments."
  local FROM_ELB="$1"
  [ -z "${FROM_ELB}" ] && fatal "${FUNCTION} \$FROM_ELB is not defined"
  local TO_ELB="$2"
  [ -z "${TO_ELB}" ] && fatal "${FUNCTION} \$TO_ELB is not defined"
  local INSTANCES="$3"
  [ -z "${INSTANCES}" ] && fatal "${FUNCTION} \$INSTANCES is not defined"
  local SKIP_CHECK="$4"
  [ -z "${SKIP_CHECK}" ] && fatal "${FUNCTION} \$SKIP_CHECK is not defined"


  if [ "${SKIP_CHECK}" != "Y" ]
  then
    elb-describe-instance-health ${FROM_ELB} > ${TMP_FILE}
    RC=$?
    [ $RC -ne 0 ] && error "[${RC}] Unable to describe Load Balancer '${FROM_ELB}' Instances"

    INSTANCE=${INSTANCES}
    #grep ${INSTANCE}
    # Loop thru instances to check in LB and spot instances
  fi

  deregister_with_elb ${FROM_ELB} ${INSTANCES}
  register_with_elb ${TO_ELB} ${INSTANCES}

  return 0
}

#------------------------------------------------------------- pre_processing --
pre_processing() {
  ec2_env

  SERVER_INDEX="${CNF_DIR}/servers${LOG_EXT}"
  PARAM_SKIP_CHECK="N"

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
  echo "Usage: ${SCRIPT_NAME}.sh -f <from-elb> -t <to-elb> -i <instance,instance> [ -s | -q | -v | --help | --version ]"
  echo ""
  echo "  Required:"
  echo "    -i         List of instances (comma separated)"
  echo "    -f         Move instances from ELB"
  echo "    -t         Move instances to ELB"
  echo ""
  echo "  Optional:"
  echo "    -s         Skip pre checking of ELB instances"
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
  while getopts f:t:i:sqv OPTION
  do
    case "$OPTION" in
      f)  PARAM_FROM_ELB=${OPTARG};;
      t)  PARAM_TO_ELB=${OPTARG};;
      i)  PARAM_INSTANCES=${OPTARG};;
      s)  PARAM_SKIP_CHECK="Y";;
      q)  QUIET="Y";; 
      v)  USE_DEBUG="Y";; 
    esac
  done
  shift `expr ${OPTIND} - 1`

  [ -z "${PARAM_INSTANCES}" ] && error "You must specify instance(s) with -i. See --help for full instructions."
  [ -z "${PARAM_FROM_ELB}" ] && error "You must specify a Load Balancer with -f. See --help for full instructions."
  [ -z "${PARAM_TO_ELB}" ] && error "You must specify a Load Balancer with -t. See --help for full instructions."

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
  process ${PARAM_FROM_ELB} ${PARAM_TO_ELB} ${PARAM_INSTANCES} ${PARAM_SKIP_CHECK}
  complete

  return 0
}

main $*

# END
