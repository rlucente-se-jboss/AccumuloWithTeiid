#!/bin/bash

. `dirname $0`/demo.conf

PUSHD ${WORK_DIR}
    # stop the processes
    pkill java -u $USER

    # cleanup the files
    rm -f *.out
POPD
