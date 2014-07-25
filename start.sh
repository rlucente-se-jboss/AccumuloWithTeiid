#!/bin/bash

. `dirname $0`/demo.conf

# make sure that sshd daemon is running
sudo service sshd start

PUSHD ${WORK_DIR}
    # start zookeeper
    JVMFLAGS="-Djava.net.preferIPv4Stack=true" testing/zookeeper-${VER_ZOOKEEP}/bin/zkServer.sh start

    # start hadoop namenode and datanode
    testing/hadoop-${VER_HADOOP}/sbin/start-dfs.sh

    # start the accumulo datastore
    testing/accumulo-${VER_ACCUMULO}/bin/start-all.sh
POPD
