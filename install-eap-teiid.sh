#!/bin/bash

. `dirname $0`/demo.conf

PUSHD ${WORK_DIR}/testing

    # install JBoss AS
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

    # copy teiid libs to accumulo installation
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

    # add the Teiid driver client jars to the SQuirreL client
    squirrel_home=${WORK_DIR}/testing/squirrel-sql-${VER_SQUIRREL}
    PUSHD ${squirrel_home}/lib
        teiid_modules_dir=${WORK_DIR}/testing/jboss-eap-${VER_EAP_INST}/modules/system/layers/base/org/jboss/teiid
        ln -s ${teiid_modules_dir}/common-core/main/teiid-common-core-${VER_TEIID}.jar .
        ln -s ${teiid_modules_dir}/client/main/teiid-client-${VER_TEIID}.jar .
    POPD

    # start zookeeper and hadoop
    JVMFLAGS="-Djava.net.preferIPv4Stack=true" zookeeper-${VER_ZOOKEEP}/bin/zkServer.sh start
    ${HADOOP_HOME}/sbin/start-dfs.sh

    # initialize accumulo and provide instance name and password
    accumulo-${VER_ACCUMULO}/bin/accumulo init <<EOF1
teiid
changeme
changeme
EOF1

POPD

# shutdown the services
${WORK_DIR}/stop.sh

