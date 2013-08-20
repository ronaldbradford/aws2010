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
  if [ -z `which ec2ver 2>/dev/null` ]
  then
    warn "EC2 tools not installed"
  else
    info "EC2 tools "`ec2ver`" using "`which ec2ver`
  fi
  if [ -z `which elb-version 2>/dev/null` ]
  then
    warn "ELB tools not installed"
  else
    info "ELB tools "`elb-version`" using "`which elb-version`
  fi
  if [ -z `which rds-version 2>/dev/null` ]
  then
    warn "RDS tools not installed"
  else
    info "RDS tools "`rds-version`" using "`which rds-version`
   fi

  if [ -z `which as-version 2>/dev/null` ]
  then
    warn "Autoscaling tools not installed"
  else
    info "AS tools "`as-version`" using "`which as-version`
   fi

  if [ -z `which mon-version 2>/dev/null` ]
  then
    warn "CloudWatch tools not installed"
  else
    info "CloudWatch tools "`mon-version`" using "`which mon-version`
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
  [ ! -f ${ARCHIVE} ] && error "Unable to obtain ${ARCHIVE} from AWS"
  unzip -q ${ARCHIVE}
 
  VER=`ls -d ec2-api-tools-*`
  [ -d "${INSTALL_DIR}/${VER}" ] && warn "Current version '${VER}' already detected" && return 0
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
  local ARCHIVE="ElasticLoadBalancing.zip"
  info "Obtaining current version of ELB Tools"
  cd ${TMP_DIR}
  rm -rf ElasticLoadBalancing*

  curl --silent -o ${ARCHIVE} http://ec2-downloads.s3.amazonaws.com/${ARCHIVE}
  [ ! -f ${ARCHIVE} ] && error "Unable to obtain ${ARCHIVE} from AWS"
  unzip -q ${ARCHIVE}

  VER=`ls -d ElasticLoadBalancing-*`
  [ -d "${INSTALL_DIR}/${VER}" ] && warn "Current version '${VER}' already detected" && return 0
  mv ${ARCHIVE} ${VER}.zip
  mv ${VER}* ${INSTALL_DIR}
  cd ${INSTALL_DIR}
  [ -f "${INSTALL_DIR}/elb" ] && rm -f ${INSTALL_DIR}/elb
  ln -s ${INSTALL_DIR}/${VER} ${INSTALL_DIR}/elb
  export AWS_ELB_HOME=${INSTALL_DIR}/elb
  export PATH=${AWS_ELB_HOME}/bin:$PATH

  info "ELB Tools from http://aws.amazon.com/developertools/2536"
  current_versions
  return 0

}

install_rds_tools() {
  local ARCHIVE="RDSCli.zip"
  info "Obtaining current version of RDS Tools"
  cd ${TMP_DIR}
  rm -rf RDSCli*

  curl --silent -o ${ARCHIVE} http://s3.amazonaws.com/rds-downloads/${ARCHIVE}
  [ ! -f ${ARCHIVE} ] && error "Unable to obtain ${ARCHIVE} from AWS"
  unzip -q ${ARCHIVE}
  VER=`ls -d RDSCli-*`
  [ -d "${INSTALL_DIR}/${VER}" ] && warn "Current version '${VER}' already detected" && return 0
  mv ${ARCHIVE} ${VER}.zip
  mv ${VER}* ${INSTALL_DIR}
  cd ${INSTALL_DIR}
  
  [ -f "${INSTALL_DIR}/rds" ] && rm -f ${INSTALL_DIR}/rds
  ln -s ${INSTALL_DIR}/${VER} ${INSTALL_DIR}/rds

  export AWS_RDS_HOME=${INSTALL_DIR}/rds
  export PATH=${AWS_RDS_HOME}/bin:$PATH
  
  info "RDS Tools from http://aws.amazon.com/developertools/2928"
  current_versions
  
  return 0
}

install_as_tools() {
  local ARCHIVE="AutoScaling-2011-01-01.zip"
  info "Obtaining current version of AutoScaling Tools"
  cd ${TMP_DIR}
  rm -rf AutoScaling*

  curl --silent -o ${ARCHIVE} http://ec2-downloads.s3.amazonaws.com/${ARCHIVE}
  [ ! -f ${ARCHIVE} ] && error "Unable to obtain ${ARCHIVE} from AWS"
  unzip -q ${ARCHIVE}
  VER=`ls -d AutoScaling-1*`
  [ -d "${INSTALL_DIR}/${VER}" ] && warn "Current version '${VER}' already detected" && return 0
  mv ${ARCHIVE} ${VER}.zip
  mv ${VER}* ${INSTALL_DIR}
  cd ${INSTALL_DIR}
  
  [ -f "${INSTALL_DIR}/as" ] && rm -f ${INSTALL_DIR}/as
  ln -s ${INSTALL_DIR}/${VER} ${INSTALL_DIR}/as

  export AWS_AUTO_SCALING_HOME=${INSTALL_DIR}/as
  export PATH=${AWS_AUTO_SCALING_HOME}/bin:$PATH
  
  info "Auto Scaling Tools from http://aws.amazon.com/developertools/2535?_encoding=UTF8&jiveRedirect=1"
  current_versions
  
  return 0
}

install_cw_tools() {
  local ARCHIVE="CloudWatch-2010-08-01.zip"
  info "Obtaining current version of AutoScaling Tools"
  cd ${TMP_DIR}
  rm -rf CloudWatch*

  curl --silent -o ${ARCHIVE} http://ec2-downloads.s3.amazonaws.com/${ARCHIVE}
  [ ! -f ${ARCHIVE} ] && error "Unable to obtain ${ARCHIVE} from AWS"
  unzip -q ${ARCHIVE}

  VER=`ls -d CloudWatch-1*`
  [ -d "${INSTALL_DIR}/${VER}" ] && warn "Current version '${VER}' already detected" && return 0
  mv ${ARCHIVE} ${VER}.zip
  mv ${VER}* ${INSTALL_DIR}
  cd ${INSTALL_DIR}
  
  [ -f "${INSTALL_DIR}/as" ] && rm -f ${INSTALL_DIR}/cw
  ln -s ${INSTALL_DIR}/${VER} ${INSTALL_DIR}/cw

  export AWS_CLOUDWATCH_HOME=${INSTALL_DIR}/cw
  export PATH=${AWS_CLOUDWATCH_HOME}/bin:$PATH
  
  info "Cloud Watch Tools from http://aws.amazon.com/developertools/2534"
  current_versions
  
  return 0
}



followup() {
  info "export EC2_HOME=${INSTALL_DIR}/ec2; export AWS_ELB_HOME=${INSTALL_DIR}/elb;export AWS_RDS_HOME=${INSTALL_DIR}/rds;export AWS_AUTO_SCALING_HOME=${INSTALL_DIR}/as; export AWS_CLOUDWATCH_HOME=${INSTALL_DIR}/cw"
  info "export PATH=\$EC2_HOME/bin:\$AWS_ELB_HOME/bin:\$AWS_RDS_HOME/bin:\$AWS_AUTO_SCALING_HOME/bin:\$AWS_CLOUDWATCH_HOME/bin:\$PATH"
  echo "export EC2_CERT=${INSTALL_DIR}/keys/cert.pem
export EC2_PRIVATE_KEY=${INSTALL_DIR}/keys/pk.pem" > ${INSTALL_DIR}/keys/env
  info "Download the AWS X.509 keys and place in ${INSTALL_DIR}/keys as cert.pem and pk.pem"
  info "Then run to verify \$ . ${INSTALL_DIR}/keys/env; ec2-describe-instances"
  return 0

}

process() {
  mkdir -p ${INSTALL_DIR}
  mkdir -p ${INSTALL_DIR}/keys
  current_versions
  install_ec2_tools
  install_elb_tools
  install_rds_tools
  install_as_tools
  install_cw_tools
  followup

  return 0
}

pre_processing() {
  if [ -z "${JAVA_HOME}" ] 
  then
    [ `uname` = "Darwin" ] && error "JAVA_HOME must be defined. For Mac OS X try \$ export JAVA_HOME=/System/Library/Frameworks/JavaVM.framework/Home/"
    error "JAVA_HOME must be defined"
  fi
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



