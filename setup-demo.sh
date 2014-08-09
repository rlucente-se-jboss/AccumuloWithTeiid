#!/bin/bash

. `dirname $0`/demo.conf

function wait_for_eap_code() {
   timeout 20 grep -q $1 <(tail -f ${WORK_DIR}/testing/jboss-eap-${VER_EAP_INST}/standalone/log/server.log)
   echo "[ Server code detected: $1 ]"
   echo
}

function wait_for_eap_stop() {
  wait_for_eap_code JBAS015950
}

function wait_for_eap_start() {
   while [ ! -f "${WORK_DIR}/testing/jboss-eap-${VER_EAP_INST}/standalone/log/server.log" ]
   do
     sleep 1
   done

  wait_for_eap_code JBAS015874
}

PUSHD ${WORK_DIR}

    # expand datasets to be imported
    mkdir -p importdata
    for data in ${DATASETS[*]}
    do
        unzip -q $data -d importdata
    done

    # start infrastructure
    ./start.sh
    wait_for_eap_start

    # run CLI scripts to setup the datasources
    for script in `ls datasources/*.cli`
    do
        testing/jboss-eap-${VER_EAP_INST}/bin/jboss-cli.sh -c --file=$script
        sleep 5
    done

    # deploy dynamic vdbs
    for vdb in `ls datasources/*-vdb.xml`
    do
        vdb_basename=`basename ${vdb}`
        cp $vdb testing/jboss-eap-${VER_EAP_INST}/standalone/deployments
        touch testing/jboss-eap-${VER_EAP_INST}/standalone/deployments/${vdb_basename}.dodeploy
    done
POPD
