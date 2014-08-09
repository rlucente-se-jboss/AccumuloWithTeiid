#!/bin/bash

. `dirname $0`/demo.conf

# stop running java processes
pkill java -u ${USER}

# run the SQuirreL SQL client uninstaller
uninstaller=${WORK_DIR}/testing/squirrel-sql-${VER_SQUIRREL}/Uninstaller/uninstaller.jar
if [ -f ${uninstaller} ]
then
    java -jar ${uninstaller}
fi

# clean up installation
rm -fr testing importdata *.out

