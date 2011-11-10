#!/bin/sh
#
#-------------------------------------------------------------------------------
# Name:     aws_cli_configure.sh
# Purpose:  Setup AWS CLI Tools
# Author:   Ronald Bradford  http://ronaldbradford.com
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Script Definition
#
SCRIPT_NAME=`basename $0 | sed -e "s/.sh$//"`
SCRIPT_VERSION="0.10 10-NOV-2011"
SCRIPT_REVISION=""

#-------------------------------------------------------------------------------
# Constants - These values never change
#

#-------------------------------------------------------------------------------
# Script specific variables
#
INSTALL_DIR="${HOME}/aws"

current_versions() {

  info "Current AWS CLI versions"
  if [ -z `which ec2ver` ]
  then
    warn "EC2 tools not installed"
  else
    info "EC2 tools "`ec2ver`" using "`which ec2ver`
  fi
  if [ -z `which elb-version` ]
  then
    warn "ELB tools not installed"
  else
    info "ELB tools "`elb-version`" using "`which elb-version`
  fi
  return 0
}

install_ec2_tools() {
  local ARCHIVE="ec2-api-tools.zip"
  info "Obtaining current version of EC2 Tools"
  cd ${TMP_DIR}
  rm -rf ec2-api-tools*
  #wget -O ec2-api-tools.zip "http://www.amazon.com/gp/redirect.html/ref=aws_rc_ec2tools?location=http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip&token=A80325AA4DAB186C80828ED5138633E3F49160D9"
  curl --silent -o ${ARCHIVE} http://s3.amazonaws.com/ec2-downloads/${ARCHIVE}
  unzip -q ${ARCHIVE}
 
  VER=`ls -d ec2-api-tools-*`
  mv ${ARCHIVE} ${VER}.zip
  mv ${VER}* ${INSTALL_DIR}
  cd ${INSTALL_DIR}
  [ -f "${INSTALL_DIR}/ec2" ] && rm -f ${INSTALL_DIR}/ec2
  ln -s ${INSTALL_DIR}/${VER} ${INSTALL_DIR}/ec2
  export EC2_HOME=${INSTALL_DIR}/ec2
  export PATH=${EC2_HOME}/bin:$PATH

  info "Docs at http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/"

  current_versions
  return 0
}

install_elb_tools(){


echo "ELB Tools from http://aws.amazon.com/developertools/2536"
wget -O ElasticLoadBalancing.zip http://ec2-downloads.s3.amazonaws.com/ElasticLoadBalancing.zip
unzip ElasticLoadBalancing.zip
cd ElasticLoadBalancing-*


# Test new version
export AWS_ELB_HOME=`pwd`
export PATH=$AWS_ELB_HOME/bin:$PATH
elb-version

}
process() {
  mkdir -p ${INSTALL_DIR}
  current_versions
  install_ec2_tools

  return 0
}

pre_processing() {
  [ -z "${JAVA_HOME}" ] && error "JAVA_HOME must be defined"
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



