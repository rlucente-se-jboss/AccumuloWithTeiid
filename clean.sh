#!/bin/bash

. `dirname $0`/demo.conf

# stop running java processes
pkill java -u ${USER}

# clean up installation
rm -fr testing importdata

