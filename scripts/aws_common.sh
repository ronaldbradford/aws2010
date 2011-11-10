#!/bin/sh
#
# common AWS functions
#

LAUNCH_SLEEP_TIME=6

#-----------------------------------------------------------------verify_ssh --
verify_ssh() {
  local FUNCTION="verify_ssh()"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function requires one argument."
  local SERVER="$1"
  [ -z "${SERVER}" ] && fatal "${FUNCTION} \$SERVER is not defined"

  info "Confirming SSH access to '${SERVER}'"
  sleep ${LAUNCH_SLEEP_TIME} 
  local COUNT=0
  while [ ${COUNT} -lt 5 ] 
  do
    ssh ${SERVER} uptime > ${TMP_FILE} 2>&1
    RC=$?
    [ ${RC} -eq 0 ] && info "SSH verified" && return 0
    warn "Unable to SSH "`cat ${TMP_FILE}`
    COUNT=`expr $COUNT + 1`
    sleep `expr 5 \* ${COUNT}`
  done
  warn "Unable to make initial connection to ${SERVER}" 

  return 1
}
  
#---------------------------------------------------------- register_with_elb --
register_with_elb() {
  local FUNCTION="register_with_elb()"
  debug "${FUNCTION} $*"
  [ $# -ne 2 ] && fatal "${FUNCTION} This function requires two arguments."
  local ELB="$1"
  [ -z "${ELB}" ] && fatal "${FUNCTION} \$ELB is not defined"
  local INSTANCE="$2"
  [ -z "${INSTANCE}" ] && fatal "${FUNCTION} \$INSTANCE is not defined"

  info "Adding Instance '${INSTANCE}' to Load Balancer '${ELB}'"

  local COUNT=0
  while [ ${COUNT} -lt 3 ] 
  do
    elb-register-instances-with-lb ${ELB} --instances ${INSTANCE} > ${TMP_FILE}
    RC=$?
    debug_file "elb-register-instances-with-lb ${ELB} --instances ${INSTANCE}" 
    [ ${RC} -eq 0 ] && return 0
    [ ${RC} -ne 0 ] && warn "Unable to register with Load Balancer "`cat ${TMP_FILE}` 
    sleep ${LAUNCH_SLEEP_TIME}
  done

  return 1
}


