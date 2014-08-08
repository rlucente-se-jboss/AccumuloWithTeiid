#!/bin/bash

. `dirname $0`/demo.conf

# stop running java processes
pkill java -u ${USER}

# setup .ssh keys for loopback connections
if [ ! -f ~/.ssh/authorized_keys ]
then
    cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
fi

# make sure that sshd daemon is running
sudo service sshd start

PUSHD ${WORK_DIR}
    # create base install dir
    rm -fr testing
    mkdir -p testing

    # install Apache Zookeeper
    tar zxf ${DIST_DIR}/zookeeper-${VER_ZOOKEEP}.tar.gz -C testing

    PUSHD testing/zookeeper-${VER_ZOOKEEP}
        PUSHD conf
            DATA_DIR=${WORK_DIR}/testing/zookeeper-${VER_ZOOKEEP}/data
            mkdir -p ${DATA_DIR}
            sed "s!^\(dataDir=\)..*!\1${DATA_DIR}!g" zoo_sample.cfg > zoo.cfg
            sed -i 's/^#\(maxClientCnxns\)..*/\1=128/g' zoo.cfg
        POPD

        JVMFLAGS="-Djava.net.preferIPv4Stack=true" bin/zkServer.sh start
    POPD

    # install Apache Hadoop
    tar zxf ${DIST_DIR}/hadoop-${VER_HADOOP}.tar.gz -C testing

    export HADOOP_PREFIX=${WORK_DIR}/testing/hadoop-${VER_HADOOP}
    export HADOOP_HOME=${HADOOP_PREFIX}
    export HADOOP_COMMON_HOME=${HADOOP_PREFIX}
    export HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop
    export HADOOP_HDFS_HOME=${HADOOP_PREFIX}
    export HADOOP_MAPRED_HOME=${HADOOP_PREFIX}
    export HADOOP_YARN_HOME=${HADOOP_PREFIX}
    export HADOOP_COMMON_LIB_NATIVE_DIR=${HADOOP_PREFIX}/lib/native
    export HADOOP_OPTS="-Djava.library.path=${HADOOP_PREFIX}/lib"

    if [ -f ~/.bashrc ]
    then
        if [ `grep HADOOP ~/.bashrc | wc -l` -eq 0 ]
        then
            echo "No Hadoop found"
            cat >> ~/.bashrc <<EOF1
export JAVA_HOME=${JAVA_HOME}
export HADOOP_PREFIX=${WORK_DIR}/testing/hadoop-${VER_HADOOP}
export HADOOP_HOME=${HADOOP_PREFIX}
export HADOOP_COMMON_HOME=${HADOOP_PREFIX}
export HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop
export HADOOP_HDFS_HOME=${HADOOP_PREFIX}
export HADOOP_MAPRED_HOME=${HADOOP_PREFIX}
export HADOOP_YARN_HOME=${HADOOP_PREFIX}
export HADOOP_COMMON_LIB_NATIVE_DIR=${HADOOP_PREFIX}/lib/native
export HADOOP_OPTS="-Djava.library.path=${HADOOP_PREFIX}/lib"
EOF1
        fi
    fi

    PUSHD ${HADOOP_CONF_DIR}
        cat > hdfs-site.xml <<EOF1
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file://${HADOOP_PREFIX}/hdfs/datanode</value>
    <description>Comma separated list of paths on the local filesystem of a DataNode where it should store its blocks.</description>
  </property>
 
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file://${HADOOP_PREFIX}/hdfs/namenode</value>
    <description>Path on the local filesystem where the NameNode stores the namespace and transaction logs persistently.</description>
  </property>
</configuration>
EOF1

        cat > core-site.xml <<EOF2
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost/</value>
    <description>NameNode URI</description>
  </property>
</configuration>
EOF2

        cat > yarn-site.xml <<EOF3
<?xml version="1.0"?>

<configuration>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>128</value>
    <description>Minimum limit of memory to allocate to each container request at the Resource Manager.</description>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>2048</value>
    <description>Maximum limit of memory to allocate to each container request at the Resource Manager.</description>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-vcores</name>
    <value>1</value>
    <description>The minimum allocation for every container request at the RM, in terms of virtual CPU cores. Requests lower than this won't take effect, and the specified value will get allocated the minimum.</description>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-vcores</name>
    <value>2</value>
    <description>The maximum allocation for every container request at the RM, in terms of virtual CPU cores. Requests higher than this won't take effect, and will get capped to this value.</description>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>4096</value>
    <description>Physical memory, in MB, to be made available to running containers</description>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>4</value>
    <description>Number of CPU cores that can be allocated for containers.</description>
  </property>
</configuration>
EOF3
    POPD

    # init the namenode (do this only once)
    mkdir -p ${HADOOP_HOME}/hdfs/namenode
    ${HADOOP_PREFIX}/bin/hdfs namenode -format

    # start hadoop namenode and datanode
    ${HADOOP_HOME}/sbin/start-dfs.sh

    # install JBoss AS
    PUSHD testing
        unzip -q ${DIST_DIR}/jboss-eap-${VER_EAP_DIST}.zip

        PUSHD jboss-eap-${VER_EAP_INST}
            # set admin and normal user
            ./bin/add-user.sh -p admin1jboss! -u admin -s
            ./bin/add-user.sh -a -p user1jboss! -u user -s -ro user,odata

            # overlay teiid
            unzip -q ${DIST_DIR}/teiid-${VER_TEIID}-jboss-dist.zip

            # patch the resteasy jars
            PUSHD modules/system/layers/base/org/jboss/resteasy/resteasy-jaxrs/main
                rm async-http-servlet-*.jar resteasy-jaxrs-*.jar

                mkdir tmp
                PUSHD tmp
                    unzip -qu ${DIST_DIR}/resteasy-jaxrs-${VER_RESTEASY}-all.zip

                    cp resteasy-jaxrs-${VER_RESTEASY}/lib/async-http-servlet-*.jar ..
                    cp resteasy-jaxrs-${VER_RESTEASY}/lib/resteasy-jaxrs-*.jar ..
                POPD
                rm -fr tmp *.index

                # fix the module
                sed -i "s/\(async-http-servlet-3.0-\)..*.jar/\1${VER_RESTEASY}.jar/g" module.xml
                sed -i "s/\(resteasy-jaxrs-\)..*.jar/\1${VER_RESTEASY}.jar/g" module.xml
            POPD

            # fix the odata4j-core jar name per TEIID-3037
            PUSHD modules/system/layers/base/org/odata4j/core/main
                oldjarname=`ls odata4j-core-*.jar`
                newjarname=`ls odata4j-core-*.jar | sed 's/redhat-redhat/redhat/g'`
                mv ${oldjarname} ${newjarname}
            POPD
        POPD

        # install accumulo
        tar zxf ${DIST_DIR}/accumulo-${VER_ACCUMULO}-bin.tar.gz
        tar zxf ${DIST_DIR}/commons-logging-${VER_COMM_LOG}-bin.tar.gz

        cp commons-logging-${VER_COMM_LOG}/commons-logging-*.jar accumulo-${VER_ACCUMULO}/lib

        ACCUMULO_LIB=${WORK_DIR}/testing/accumulo-${VER_ACCUMULO}/lib
        PUSHD jboss-eap-${VER_EAP_INST}/modules/system/layers/base/org/jboss/teiid
            cp translator/accumulo/main/translator-accumulo-*.jar \
               common-core/main/teiid-common-core-*.jar \
               client/main/teiid-client-*.jar \
               api/main/teiid-api-*.jar \
               main/teiid-engine-*.jar \
               main/teiid-runtime-*.jar \
               main/nux-*.jar \
               main/saxonhe-*.jar ${ACCUMULO_LIB}
        POPD


        # fix accumulo modules in jboss-eap-6.1 to use latest
        # accumulo 1.6.0 libs otherwise get errors on insert
        PUSHD jboss-eap-${VER_EAP_INST}/modules/system/layers/base/org/apache/accumulo/main
            rm -f *.index accumulo-*-1.5.0.jar
            cp ${ACCUMULO_LIB}/accumulo-core.jar accumulo-core-1.6.0.jar
            cp ${ACCUMULO_LIB}/accumulo-fate.jar accumulo-fate-1.6.0.jar
            cp ${ACCUMULO_LIB}/accumulo-trace.jar accumulo-trace-1.6.0.jar
           
            sed -i 's/\(<resource-root ..*\)-1.5.0/\1-1.6.0/g' module.xml
            sed -i 's/\(<module name="javax.api"\/>\)/\1<module name="com.google.guava"\/>/g' module.xml 
        POPD

        PUSHD accumulo-${VER_ACCUMULO}
            cp conf/examples/512MB/standalone/* conf

            # add env vars to accumulo-env.sh
            sed -i 's/^#! \/usr\/bin\/env bash//g' conf/accumulo-env.sh

            cat > tmp.$$.1 <<EOF5
#! /usr/bin/env bash

JAVA_HOME=${JAVA_HOME}
HADOOP_HOME=${WORK_DIR}/testing/hadoop-${VER_HADOOP}
ZOOKEEPER_HOME=${WORK_DIR}/testing/zookeeper-${VER_ZOOKEEP}
ACCUMULO_HOME=${WORK_DIR}/testing/accumulo-${VER_ACCUMULO}
HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop/

EOF5
            cat tmp.$$.1 conf/accumulo-env.sh > tmp.$$.2
            mv tmp.$$.2 conf/accumulo-env.sh
            rm -f tmp.$$.*

            # set properties in accumulo-site.xml
            sed -i 's/\(<value>\)secret/\1changeme/g' conf/accumulo-site.xml
            sed -i 's/^<\/configuration>//g' conf/accumulo-site.xml

            cat >> conf/accumulo-site.xml <<EOF6
  <property>
    <name>master.port.client</name>
    <value>9995</value>
  </property>
</configuration>
EOF6

            # initialize accumulo and provide instance name and password
            bin/accumulo init <<EOF7
teiid
changeme
changeme
EOF7
            # start the accumulo datastore
            bin/start-all.sh
        POPD
    POPD

    # install SQuirreL SQL Client
    squirrel_home=${WORK_DIR}/testing/squirrel-sql-${VER_SQUIRREL}
    sed -i "s!\(<installpath>\)..*\(</installpath>\)!\1$squirrel_home\2!g" squirrel-sql.xml

    java -jar ${DIST_DIR}/squirrel-sql-${VER_SQUIRREL}-standard.jar squirrel-sql.xml

    # add the Teiid driver client jars to the SQuirreL client
    PUSHD ${squirrel_home}/lib
        teiid_modules_dir=${WORK_DIR}/testing/jboss-eap-${VER_EAP_INST}/modules/system/layers/base/org/jboss/teiid
        ln -s ${teiid_modules_dir}/common-core/main/teiid-common-core-${VER_TEIID}.jar .
        ln -s ${teiid_modules_dir}/client/main/teiid-client-${VER_TEIID}.jar .
    POPD
POPD
