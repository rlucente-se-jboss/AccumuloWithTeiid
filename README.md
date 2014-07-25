AccumuloWithTeiid
=================

Simple project demonstrating accessing Accumulo with Teiid

Install Accumulo and Launch
---------------------------

Accumulo requires a larger number of open files than the
normal default.  To enable this, create a file called
'/etc/security/limits.d/99-nofile.conf' with the following contents:

    #
    # Default limit for number of open files
    #
    *       soft    nofile  65536
    *       hard    nofile  65536

After the file is created, fix the SELinux context using:

    sudo restorecon -vFr /etc/security/limits.d

and reboot your system so the new settings take effect.

Additionally, the sshd daemon should be running.  Prior to starting
Accumulo, start the sshd daemon using the command:

    sudo service sshd start

Edit the contents of demo.conf to make sure that the settings match
your desired installation.  The install.sh script will install hadoop,
data virtualization, accumulo, and zookeeper in the same directory as
the install.sh script.  To install:

    ./clean.sh
    ./install.sh

To start and stop Accumulo after it is installed, simply use the commands:

    ./start.sh
    ./stop.sh

Configure JBDS 7.1.1
--------------------

To do this example, you'll need Teiid Designer 8.5 which includes support
for Accumulo.  That release requires additional dependencies.

First, install the current Teiid Designer tooling by selecting the
"Software/Update" on the "JBoss Central" pane.  Select the "JBoss
Data Virtualization Development" and click the "Install" button.
Select "Next>" and accept the defaults including the license agreement.
Restart JBDS when prompted.

Select "Help->Install New Software...".  Click the "Add..." button and
put the BIRT Update Site URL into the Location field:

    http://download.eclipse.org/birt/update-site/4.3

Select the "BIRT 4.3 Reporting SDK" and select the "Next>" button.
Select defaults and accept the license to install the tooling.
Restart JBDS when prompted.

Select "Help->Install New Software...".  Click the "Add..." button and
put the Teiid Designer URL into the Location field:

    http://download.jboss.org/jbosstools/updates/release/kepler/integration-stack/teiiddesigner/8.5.0.Final/

Select the "Teiid Designer" and select the "Next>" button.  Select
defaults and accept the license to install the tooling.  Restart JBDS
when prompted.

