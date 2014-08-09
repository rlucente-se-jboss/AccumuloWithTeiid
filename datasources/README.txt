For the SSA dataset, make sure that this directory contains the file:

    http://www.ssa.gov/oact/babynames/state/namesbystate.zip

Also, make sure to update the DATASETS array in the demo.conf file in
the parent directory to contain any data files listed in this directory.

Any .cli files in this directory will be run by the setup-demo.sh script
in the parent directory to create the appropriate datasources and resource
adapters for the demo.

Any .xml files in this directory are assumed to be dynamic vdbs that
will be deployed as part of the demo setup.

The order for these actions are:

    1. Extract any datasets to the importdata directory
    2. Run cli scripts to create resource adapters and datasources
    3. Deploy dynamic vdbs

