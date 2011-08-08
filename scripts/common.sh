#!/bin/sh
#-------------------------------------------------------------------------------
# Name:     common.sh
# Purpose:  Common scripting functions used by all scripts
# Website:  http://ronaldbradford.com
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
COMMON_SCRIPT_VERSION="0.11 08-AUG-2011"
COMMON_SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#
FATAL="FATAL"
ERROR="ERROR"
WARN="WARN "
INFO="INFO "
DEBUG="DEBUG"
OK="OK"

LOGGING_LEVELS="${FATAL} ${ERROR} ${WARN} ${INFO} ${DEBUG}"
DEFAULT_LOG_DATE_FORMAT="+%Y%m%d %H:%M:%S %z"
LOG_EXT=".txt"
DATE_TIME_FORMAT="+%Y%m%d.%H%M"

SEP=","
DATA_EXT=".csv"

#-------------------------------------------------------------------------------
# Base Variables
#
DATE_TIME=`date ${DATE_TIME_FORMAT}`
DATE_TIME_TZ=`date ${DATE_TIME_FORMAT}%z`
[ -z "${TMP_DIR}" ] && TMP_DIR="/tmp"
TMP_FILE="${TMP_DIR}/${SCRIPT_NAME}.tmp.$$"
STOP_FILE="${TMP_DIR}/${SCRIPT_NAME}.stop"

USER_ID=`id -u`
[ "${USER_ID}" -eq 0 ] && ROOT_USER="Y"

FULL_HOSTNAME=`hostname 2>/dev/null`
SHORT_HOSTNAME=`hostname -s 2>/dev/null`

[ -z "${LOG_DATE_FORMAT}" ] && LOG_DATE_FORMAT="${DEFAULT_LOG_DATE_FORMAT}"

DEFAULT_LOG_COMPRESS_DAYS=5
DEFAULT_LOG_DELETE_DAYS=30
DEFAULT_LOCK_TIMEOUT=60

DEFAULT_PRODUCT="mysql"
DEFAULT_MYSQL_USER="aba"

#----------------------------------------------------------------cleanup_exit --
# Exit the program, reporting exit code and clean up default tmp file
# Was named leave() by conflicts with BSD command
#
cleanup_exit() {
  local FUNCTION="common:cleanup_exit()"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function requires one argument."
  local EXIT_CODE="$1"
  [ -z "${EXIT_CODE}" ] && fatal "${FUNCTION} \$EXIT_CODE is not defined"
  debug "${FUNCTION} exiting script with '${EXIT_CODE}'"

  service_unlock

  [ $EXIT_CODE -ne 0 ] && info "Exiting with status code of '${EXIT_CODE}'"
  [ ! -z "${TMP_FILE}" ] && rm -f ${TMP_FILE}
  [ ! -z "${STOP_FILE}" ] && rm -f ${STOP_FILE}

  exit ${EXIT_CODE}
}

#------------------------------------------------------------------------ log --
# Internal function for logging various levels of output
#
log() {
  local FUNCTION="common:log()"
  [ $# -lt 2 ] && fatal "${FUNCTION} This function requires at least two arguments."
  local LEVEL="$1"; shift
  local OUTPUT
  OUTPUT=$*
  [ -z "${LEVEL}" ] && fatal "${FUNCTION} \$LEVEL is not defined"
  [ -z "${OUTPUT}" ] && fatal "${FUNCTION} \$OUTPUT is not defined"

  [ -z "${LOG_DATE_FORMAT}" ] && fatal "${FUNCTION} Global \$LOG_DATE_FORMAT is not defined"
  local LOG_DT
  LOG_DT=`date "${LOG_DATE_FORMAT}"`

  #Causes potential infinite loop
  #[ `echo ${LOGGING_LEVELS} | grep ${LEVEL} | wc -l` -ne 0 ] && fatal "log() specified \$LEVEL=\"${LEVEL}\" is not valid"

  echo "${LOG_DT} ${LEVEL} [${SCRIPT_NAME}] ${OUTPUT}"

  return 0
}

#---------------------------------------------------------------------- fatal --
# Log a fatal message
#
fatal() {
  local FUNCTION="common:fatal()"
  [ $# -lt 1 ] && fatal "${FUNCTION} This function requires at least one argument."
  local OUTPUT
  OUTPUT=$*
  [ -z "${OUTPUT}" ] && fatal "${FUNCTION} \$OUTPUT is not defined"

  log "${FATAL}" "INTERNAL ERROR: " ${OUTPUT}
  local ERROR_CODE="100"
  cleanup_exit ${ERROR_CODE}

  return 0
}

#---------------------------------------------------------------------- error -- 
# Log an error message
#
error() {
  local FUNCTION="common:error()"
  [ $# -lt 1 ] && fatal "${FUNCTION} This function requires at least one argument."
  local OUTPUT
  OUTPUT=$*
  [ -z "${OUTPUT}" ] && fatal "${FUNCTION} \$OUTPUT is not defined"

  log "${ERROR}" ${OUTPUT}
  local ERROR_CODE="1"
  cleanup_exit ${ERROR_CODE}

  return 0
}

#----------------------------------------------------------------------- warn -- 
# Log a warning message
#
warn() {
  local FUNCTION="common:warn()"
  [ $# -lt 1 ] && fatal "${FUNCTION} This function requires at least one argument."
  local OUTPUT
  OUTPUT=$*
  [ -z "${OUTPUT}" ] && fatal "${FUNCTION} \$OUTPUT is not defined"

  log "${WARN}" ${OUTPUT}

  return 0
}

#----------------------------------------------------------------------- info -- 
# Log an information message
#
info() {
  local FUNCTION="common:info()"
  [ $# -lt 1 ] && fatal "${FUNCTION} This function requires at least one argument."
  local OUTPUT
  OUTPUT=$*
  [ -z "${OUTPUT}" ] && fatal "${FUNCTION} \$OUTPUT is not defined"

  [ -z "${QUIET}" ] && log "${INFO}" ${OUTPUT}
 
  return 0
}

#---------------------------------------------------------------------- debug -- 
# Log a debugging message
#
debug() {
  local FUNCTION="common:debug()"
  [ $# -lt 1 ] && fatal "${FUNCTION} This function requires at least one argument."
  local OUTPUT
  OUTPUT=$*
  [ -z "${OUTPUT}" ] && fatal "${FUNCTION} \$OUTPUT is not defined"

  [ ! -z "${USE_DEBUG}" ] && log "${DEBUG}" ${OUTPUT}

  return 0
}

#--------------------------------------------------------------- manages_logs -- 
# Manage logs to compress and purge
#
manage_logs() {
  local FUNCTION="common:manage_logs()"
  [ -z "${DEFAULT_LOG_COMPRESS_DAYS}" ] && fatal "${FUNCTION} \$DEFAULT_LOG_COMPRESS_DAYS is not defined"
  [ -z "${DEFAULT_LOG_DELETE_DAYS}" ] && fatal "${FUNCTION} \$DEFAULT_LOG_DELETE_DAYS is not defined"
  info "Compressing and purging logs"

  compress_logs ${DEFAULT_LOG_COMPRESS_DAYS}
  purge_logs ${DEFAULT_LOG_DELETE_DAYS}

  return 0
}

#-------------------------------------------------------------- compress_logs -- 
# Compress logs for a given number of days
#
compress_logs() {
  local FUNCTION="common:compress_logs()"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function requires one argument."
  local DAYS="$1"
  [ -z "${DAYS}" ] && fatal "${FUNCTION} \$DAYS is not defined"
  find ${LOG_DIR} -maxdepth 1 -type f -name "*${LOG_EXT}" -mtime +${DAYS} -print -exec gzip {} \; > /dev/null 2>&1

  return 0
}

#----------------------------------------------------------------- purge_logs -- 
# Purge logs for a given number of days
#
purge_logs() {
  local FUNCTION="common:purge_logs()"
  [ $# -ne 1 ] && fatal "${FUNCTION} This function requires one argument."
  local DAYS="$1"
  [ -z "${DAYS}" ] && fatal "${FUNCTION} \$DAYS is not defined"
  find ${LOG_DIR} -maxdepth 1 -type f -name "*${LOG_EXT}.gz" -mtime +${DAYS} -print -exec rm -f {} \; > /dev/null 2>&1

  return 0
}

#------------------------------------------------------------------- commence -- 
# Commence Script Logging with starting message
#
commence() {
  local FUNCTION="common:commence()"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts no arguments."

  [ -f "${STOP_FILE}" ] && error "An existing stop file '${STOP_FILE}' exists, remove this to start processing"
  START_SEC=`date +%s`
  info "Script started (Version: ${SCRIPT_VERSION})"

  return 0
}

#------------------------------------------------------------------- complete -- 
# Complete Script Logging with completed message
#
complete() {
  local FUNCTION="common:complete()"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts no arguments."

  END_SEC=`date +%s`
  [ -z "${START_SEC}" ] && warn "${FUNCTION} was not used to determine starting time of script" && TOTAL_SECS="[Unknonwn]"
  [ -z" ${TOTAL_SECS}" ] && TOTAL_SECS=`expr ${END_SEC} - ${START_SEC}`
  info "Script completed successfully (${TOTAL_SECS} secs)"

  cleanup_exit 0
}

#------------------------------------------------------------- set_base_paths --
# Set the essential paths for all scripts
# Scripts can be called from 
#    /path/to/scripts/name.sh
#    [./]name.sh
#    scripts/name.sh
#
set_base_paths() {
  local FUNCTION="common:set_base_paths()"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts no arguments."

  [ -z "${BASE_DIR}" ] && BASE_DIR=`dirname $0 | sed -e "s/scripts//"`
  if [ "${BASE_DIR}" = "." ]
  then
    BASE_DIR=".."
  elif [ -z "${BASE_DIR}" ] 
  then
    BASE_DIR="."
  fi

  [ -z "${BASE_DIR}" ] && fatal "${FUNCTION} Unable to determine BASE_DIR"

  SCRIPT_DIR=${BASE_DIR}/scripts
  CNF_DIR=${BASE_DIR}/etc
  [ -z "${LOG_DIR}" ] && LOG_DIR="${BASE_DIR}/log"

  debug "SCRIPT_DIR=${SCRIPT_DIR}"
  debug "LOG_DIR=${LOG_DIR}"
  debug "CNF_DIR=${CNF_DIR}"
  if [ ! -d "${CNF_DIR}" ] 
  then
    warn "The required configuration directory '${CNF_DIR}' was not found, creating"
    run "Creating required configuration directory" mkdir -p ${CNF_DIR}
  fi
  if [ ! -d "${LOG_DIR}" ] 
  then
    warn "The required log directory '${LOG_DIR}' was not found, creating"
    run "Creating required log directory" mkdir -p ${LOG_DIR}
  fi

  COMMON_ENV_FILE="${CNF_DIR}/.common"
  [ -f "${COMMON_ENV_FILE}" ] && . ${COMMON_ENV_FILE}
  DEFAULT_CNF_FILE="${CNF_DIR}/${SCRIPT_NAME}.cnf"
  DEFAULT_LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.${DATE_TIME}${LOG_EXT}"
  DEFAULT_HOST_LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.${DATE_TIME}.${SHORT_HOSTNAME}${LOG_EXT}"
  DEFAULT_HOST_CNF_FILE="${CNF_DIR}/${SCRIPT_NAME}.${SHORT_HOSTNAME}.cnf"

  return 0
}

#-------------------------------------------------------------------- version --
#  Display to stdout the Script Version details and exit
#
version() {
  local FUNCTION="common:version()"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts no arguments."

  echo "Name: ${SCRIPT_NAME}.sh  Version:  ${SCRIPT_VERSION}  Revision: ${SCRIPT_REVISION}"

  return 0
}

#-------------------------------------------------------- check_for_long_args --
#  Check for --long arguments
#
check_for_long_args() {

  while [ ! -z "$1" ]
  do
    [ "$1" = "--version" ] && version && exit 0
    [ "$1" = "--help" ] && help && exit 0
    shift
  done

  return 0
}

#------------------------------------------------------------ check_stop_file --
#  Check for Stop file and exit nicely
#
check_stop_file() {

  if [ -f "${STOP_FILE}" ]
  then
    warn "A stop file was provided to stop script processing."
    complete
  fi

  return 0
}

#-------------------------------------------------------------- service_lock --
# Lock to the current service so only one instance can run
#
service_lock() {
  local FUNCTION="common:service_lock()"
  [ $# -lt 1 -o $# -gt 2 ] && fatal "${FUNCTION} This function accepts one or two parameters"
  local LOCK_TYPE="$1"
  local LOCK_TIMEOUT="$2"
  # Verify parameters
  [ -z "${LOCK_TYPE}" ] && fatal "${FUNCTION} \$LOCK_TYPE is not defined"

  # Required system default variables
  [ -z "${DEFAULT_LOCK_TIMEOUT}" ] && fatal "${FUNCTION} Global \$DEFAULT_LOCK_TIMEOUT is not defined"
  [ -z "${SCRIPT_NAME}" ] && fatal "${FUNCTION} Global \$SCRIPT_NAME is not defined"

  # function variables
  [ -z "${LOCK_TIMEOUT}" ] && LOCK_TIMEOUT=${DEFAULT_LOCK_TIMEOUT}
  LOCK_FILE="${TMP_DIR}/${SCRIPT_NAME}.${LOCK_TYPE}.lock"
  local LOCK_TIME
  LOCK_TIME=`date +%s`

  if [ -f "${LOCK_FILE}" ]
  then
    warn "An existing lock file exists"
    local EXISTING_LOCK_TIME
    EXISTING_LOCK_TIME=`head -1 ${LOCK_FILE}`
    [ `expr ${EXISTING_LOCK_TIME} + ${LOCK_TIMEOUT}` -gt ${LOCK_TIME} ] && error "Another instance of this process is running '${SCRIPT_NAME}'/'${LOCK_TYPE}'"
    warn "Another instance of '${SCRIPT_NAME}'/'${LOCK_TYPE}' was found but it now stale (> '${LOCK_TIMEOUT}' secs)"
    rm -f ${LOCK_FILE}
  fi
  echo "${LOCK_TIME}" > ${LOCK_FILE}

  return 0
}

#------------------------------------------------------------ service_unlock --
# Unlock the current service allowing another process to run
#
service_unlock() {
  local FUNCTION="common:service_unlock()"
  [ $# -ne 0 ] && fatal "${FUNCTION} This function accepts no arguments."

  [ ! -z "${LOCK_FILE}" ] && [ ! -f "${LOCK_FILE}" ] && warn "No lock file found."
  rm -f ${LOCK_FILE}
  LOCK_FILE=""  

  return 0
}

#----------------------------------------------------------------------- run --
# Run a given command with implied error checking
#
run() {
  local FUNCTION="common:run()"
  [ $# -lt 2 ] && fatal "${FUNCTION} This function requires at least two arguments."
  local RUN_DESCRIPTION="$1"
  shift
  local RUN_CMD="$*"

  debug "About to run '${RUN_DESCRIPTION}' with '${RUN_CMD}'"
  
  ${RUN_CMD} > ${TMP_FILE} 2>&1
  RC=$?

  [ ${RC} -ne 0 ] && [ ! -z "${USE_DEBUG}" ] && cat ${TMP_FILE}
  [ ${RC} -ne 0 ] && error "Unable to run command '${RUN_DESCRIPTION}' successfully. Exit code '${RC}'"

  return 0
}

#--------------------------------------------------------- verify_mysql_login --
# Check for authentication to connect to mysql
#
verify_mysql_login() {
  [ -z "${MYSQL_AUTHENTICATION}" ] && error "There is no MYSQL_AUTHENTICATION to execute mysql commands"

  return 0
}

#---------------------------------------------------------------- mysql_home --
#  Check for defined MYSQL_HOME and PATH
#
mysql_home() {
  [ -z "${MYSQL_HOME}" ] && error "MYSQL_HOME must be specified" 
  [ -z `which mysql` ] && error "mysql client not in path, \$MYSQL_HOME/bin should be added to PATH"
  [ -z `which mysqladmin` ] && error "mysqladmin not in path, \$MYSQL_HOME/bin should be added to PATH"

  return 0
}

#------------------------------------------------------------------- ec2_env --
#  Check for correctly configured EC2 API tools
#
ec2_env() {
  [ -z "${EC2_PRIVATE_KEY}" ] && [ -z "${EC2_CERT}" ] && error "EC2_PRIVATE_KEY and EC2_CERT must be specified"
  [ -z "${EC2_PRIVATE_KEY}" ] && error "EC2_PRIVATE_KEY must be specified"
  [ -z "${EC2_CERT}" ] && error "EC2_CERT must be specified"


  [ -z "${AWS_ELB_HOME}" ] && error "AWS_ELB_HOME must be specified"
  [ -z "${JAVA_HOME}" ] && error "JAVA_HOME must be specified"

  [ -z `which ec2-describe-instances` ] && error "ec2-describe-instances not in path, Ensure ec2-api tools added to PATH"
  [ -z `which elb-describe-lbs` ] && error "elb-describe-lbs not in path, Ensure elb-api tools added to PATH"
  return 0
}
# END
