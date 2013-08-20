#!/bin/sh

instance() {
  export INSTANCE_ID=`curl --silent http://169.254.169.254/latest/meta-data/instance-id`
  echo ${INSTANCE_ID}
}

