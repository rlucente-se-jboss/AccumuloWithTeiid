AccumuloWithTeiid
=================

Simple project demonstrating accessing Accumulo with Teiid.
The scripts automate the installation and setup of Hadoop,
Zookeeper, Accumulo, and Teiid as described in this
[article](https://community.jboss.org/wiki/ApacheAccumuloWithTeiid).

This project updates the versions of the various components.
Specifically, this now uses:

* Accumulo 1.6.0
* Commons Logging 1.2
* Hadoop 2.4.1
* Teiid 8.8.0 (with RestEasy 2.3.6 Patch)
* Zookeeper 3.4.6

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

Wait for a console message stating that accumulo-babies-vdb.xml has
been deployed.

To start and stop Accumulo after it is installed, simply use the commands:

    ./start.sh
    ./stop.sh

Test the Installation
---------------------

Instead of using the Teiid Designer, the install.sh script follows step 2
option 2 in the [article](https://community.jboss.org/wiki/ApacheAccumuloWithTeiid).

The install.sh script uses an EAP command-line interface script to
deploy the necessary resource adapters and register them with JNDI.
It then deploys a dynamic vdb enabling access to both the file view
and the accumulo view.  A Teiid user is configured in the application
security realm with the name and password of:

    user/user1jboss!

This user has both the user and the odata roles so the odata server
features of Teiid can be used to confirm that everything is working
properly.  To do this, open Firefox and browse to the URLs:

    http://localhost:8080/babynames/file.babies?$format=json
    http://localhost:8080/babynames/accumulo.babies?$format=json

The URL follows the pattern:

    http://<server>:<port>/<vdb-name>/<model>.<table>

The optional format directive renders the output as json.  For the above
URLs, the file model will have data and the accumulo model will be empty.

Enable SQuirreL Client for Teiid
--------------------------------

Launch the SQuirreL SQL client using the command:

    testing/squirrel-sql-3.5.3/squirrel-sql.sh

On the main window, click the "Drivers" tab along the left hand side.
Click the "+" icon to add a new driver.

On the "Add Driver" dialog, put the following values in the named fields:

    Name:  Teiid Driver
    Example URL:  jdbc:teiid:babynames@mm://localhost:31000

The pattern for Teiid database connection strings is:

    jdbc:teiid:<vdb-name>@mm[s]://<host>:<port>;[prop-name=prop-value;]*

On the same dialog, select the "Extra Class Path" tab and click the
"Add" button.  Browse to the Teiid driver at:

    <install-dir>/testing/squirrel-sql-3.5.3/lib/teiid-client-8.8.0.Final.jar

Next, click on the "List Drivers" button to populate the "Class Name"
field then press "OK".  In the status window, you should see that the
driver was successfully registered.

Populate the Accumulo Store
---------------------------

With SQuirrel SQL client running, import the babynames data into the
Accumulo store.  To do this, click on the "Aliases" tab on the left
hand side and then click "+" to create a new alias.  Set the fields to
the following:

    Name:  babynames
    Driver:  Teiid Driver
    URL:  jdbc:teiid:babynames@mm://localhost:31000
    User Name:  user
    Password:  user1jboss!

Leave the other defaults and press OK then press "Connect".

Select the "SQL" tab and type the following SQL statement to populate
the accumulo data store:

    insert into accumulo.babies (id, name, state, gender, birthyear, occurences)  
    select f.id, f.name, f.state, f.gender, f.birthyear, f.occurences from file.babies as f;

Click the running man icon to execute the SQL statement.

