# tiysoo
> This Is Your Satellite On OpenShift

This is a very experimental work-in-progress project to deploy Red Hat
Satellite 6 on OpenShift.

This project is currently only targeting content management and
content hosting use-cases, not anything requiring tftp, dhcp or
similar network services.

We currently create one single monolithic container running all
Satellite services, including foreman, postgresql, mongodb, pulp and
more.

## Quickstart

Create an OpenShift project called `satellite`.  The satellite
container requires the ability to run as root.  Enable this in your
`satellite` project like so:

    $ oc adm policy add-scc-to-user anyuid -z default
    
Now import the satellite template:

    $ curl -o - https://raw.githubusercontent.com/atgreen/tiysoo/master/satellite-template.yml | oc create -f -
    
The SatefulSet defined in this template is currently configured to
request three persistent volumes: two 1Gi PVs and a 100Gi PV.  Make
sure your cluster is able to provision those.

Now you should be able to instantiate satellite instances via the
service catalog web interface, or via the command line, like so:

    $ oc new-app satellite-template -p RHSM_USERNAME=myusername \
                                    -p RHSM_PASSWORD=mypassword \
                                    -p RHSM_POOL=8a85f99968334b4f21683f0af5966e71 \
                                    -p FOREMAN_ADMIN_PASSWORD=passw0rd \
                                    -p APPLICATION_DOMAIN=satellite.apps.example.com
    --> Deploying template "satellite/satellite-template" to project satellite
    
         Red Hat Satellite
         ---------
         Red Hat Satellite Server
    
         The following service has been created in your project: satellite.
         
         For more information about using this template, including OpenShift considerations, see https://github.com/atgreen/tiysoo/README.md.
    
         * With parameters:
            * Name=satellite
            * Application Hostname=satellite.apps.example.com
            * Git Repository URL=http://github.com/atgreen/tiysoo.git
            * RHSM_USERNAME=myusername
            * RHSM_PASSWORD=mypassword
            * RHSM_POOL=8a85f99968334b4f21683f0af5966e71
            * FOREMAN_ADMIN_PASSWORD=passw0rd
    
    --> Creating resources ...
        imagestream.image.openshift.io "satellite" created
        buildconfig.build.openshift.io "satellite" created
        service "satellite" created
        route.route.openshift.io "satellite" created
        statefulset.apps "satellite" created
    --> Success
        Build scheduled, use 'oc logs -f bc/satellite' to track its progress.
        Access your application via route 'satellite.apps.example.com' 
        Run 'oc status' to view your app.
    
The installation and configuration process will take a long time.
Please be patient.

Satellite on OpenShift has only been lightly tested, and there are
many obvious improvements that could be made to this project.  Please
feel free to file Issues and submit Pull Requests.

## Challenges and Solutions

Satellite is a great example of a typical legacy enterprise
application architecture.  A typical deployment includes a web
application, a postgreql DB, a mongodb instance, and supporting
stateful technologies like pulp and celery.


### Challenge 1: Accessing the Satellite RPM content

RHEL container images inherit their subscriptions from the underlying
RHEL host.  Because we're running on an OpenShift platform and don't
want to enable the Satellite repos for each host, we need a little
work-around; a way to sever the connection between RHEL container and
host.  

The way to do this is by deleting `/etc/rhsm-host` in your Dockerfile.
Once this is done, you can safely register the container to Red Hat
(or another Satellite), attach to the right pool, enable the right
repos, and download your content.


### Challenge 2: Running multiple processes in a container

Unlike your simple springboot, python or tomcat workload, a Satellite
server consists of multiple stateful applications running side-by-side
in a single VM.  These include PostgreSQL, MongoDB, The Foreman /
Katello, Pulp, Celery and more.  These services are tightly coupled
and don't scale independently from one another.

Because we're aiming for a simple lift-and-shift, rather than custom
build individual container images for each component, we're going to
run them all in a single container deployment using systemd.  Recent
versions of the RHEL container images support systemd.  All you need
to do is set `CMD` in your Dockerfile to `/bin/init`.


### Challenge 3: The install requires a running system

The Satellite installer is a complex piece of software that involves
running services at install time -- not something you can easily
handle in a Dockerfile-style installation.

The answer here is to split the installation into two phases.  Phase
One is when we install all of the required RPMs.  This is done with a
simple Dockerfile that downloads all of the necessary RPMS.  Phase Two
is where we actually run the `satellite-install` process.  The trick
here is to use a [systemd unit file](https://github.com/atgreen/tiysoo/blob/master/root/etc/systemd/system/install-satellite.service) to kick off the installation
process as a "one-shot" process.  Remember, our container is booting
into systemd because we need to start multiple services (postgresql,
etc).  


### Challenge 3: Managing state

The Satellite installer writes all over the filesystem, including /etc
and /var.  Those directories are provided by the container image, and
so normally anything written there will vanish when the container
shuts down.  In order to preserve change made at install-time, we need
to map these directories to persistent volumes.  The approach I took
in tiysoo is to run an init container that copies all of /etc and /var
to two persistent volumes that we claim.  This happens before the
container starts again to run the installer.  Now, every change made
under those directories will persist on the PV.


### Challenge 4: Certificate handling

We need Satellite to provide SSL certs for the ingress route, in
addition to whatever it builds by default at install time based on the
names it sees within the OCP namespace.  Fortunately, Satellite
provides katello-ssl-tool, which is capable of generating additional
certificates that you can apply to the system by running the install
again.  See the tyisoo-install script for details.

### Future Challenges

* How do we handle upgrades?
* How do we handle backups?
* Can we decouple any of the services - say postgresql - to leverage an HA postgresql deployment?
* etc etc etc
