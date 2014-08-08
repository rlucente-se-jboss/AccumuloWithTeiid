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

    # expand the dataset to be imported
    mkdir -p importdata
    PUSHD importdata
        unzip -q ${DIST_DIR}/namesbystate.zip
    POPD

    # launch EAP and setup the datasources
    testing/jboss-eap-${VER_EAP_INST}/bin/standalone.sh -c standalone-teiid.xml &
    wait_for_eap_start

    testing/jboss-eap-${VER_EAP_INST}/bin/jboss-cli.sh -c --file=${WORK_DIR}/setup-file-and-accumulo-ds.cli
    sleep 5

    # create the dynamic vdb
    cat > accumulo-babies-vdb.xml <<EOF8
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>  
<vdb name="babynames" version="1">  
    <model name="accumulo">  
        <source name="node1" translator-name="accumulo" connection-jndi-name="java:/accumulo-ds" />  
        <metadata type="DDL"><![CDATA[          
            CREATE FOREIGN TABLE babies ( 
                  id integer PRIMARY KEY OPTIONS (SEARCHABLE 'All_Except_Like', "teiid_accumulo:CF" 'id'), 
                  name varchar(25) OPTIONS (SEARCHABLE 'All_Except_Like', "teiid_accumulo:CF" 'name'), 
                  state varchar(25) OPTIONS (SEARCHABLE 'All_Except_Like', "teiid_accumulo:CF" 'state'), 
                  gender char(1) OPTIONS (SEARCHABLE 'All_Except_Like', "teiid_accumulo:CF" 'gender'), 
                  birthyear integer OPTIONS (SEARCHABLE 'All_Except_Like', "teiid_accumulo:CF" 'birthyear'), 
                  occurences integer OPTIONS (SEARCHABLE 'All_Except_Like', "teiid_accumulo:CF" 'occurences') 
            ) OPTIONS (UPDATABLE TRUE) 
            ]]>  
        </metadata>  
    </model>  
    <model name="file_source">  
        <source name="file" translator-name="file" connection-jndi-name="java:/file-ds" />  
    </model>  
    <model name="file" visible="true" type="VIRTUAL">  
        <metadata type="DDL"><![CDATA[          
            CREATE VIEW babies (id integer PRIMARY KEY, 
                                name varchar(25),            
                                state varchar(25), 
                                gender char(1), 
                                birthyear integer, 
                                occurences integer 
            ) AS SELECT ROW_NUMBER() OVER (ORDER BY A.state) as id , A.name, A.state, A.gender, A.birthyear,  A.occurences FROM 
            (EXEC file_source.getTextFiles('VA.TXT')) AS f,              
            TEXTTABLE(f.file COLUMNS state string, gender char, birthyear integer, name string, occurences integer) AS A;     
            ]]>  
        </metadata>  
    </model>  
</vdb>
EOF8

    # deploy the vdb
    mv accumulo-babies-vdb.xml testing/jboss-eap-${VER_EAP_INST}/standalone/deployments
    touch testing/jboss-eap-${VER_EAP_INST}/standalone/deployments/accumulo-babies-vdb.xml.dodeploy
POPD
