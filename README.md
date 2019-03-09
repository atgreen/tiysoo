# sicko
> Satellite In Containers/Kubernetes/OpenShift

This is a very experimental work-in-progress project to deploy Red Hat
Satellite 6 on OpenShift.

This project is currently only targeting content management and
content hosting use-cases, not anything requiring tftp, dhcp or
similar network services.

We currently create one single monolithic container running all
Satellite services, including foreman, postgresql, mongodb, pulp and
more.

## Quickstart

Create an OpenShift project called `satellite`.  Search through the
source for 'labdroid' and add your own domain info.

    $ oc create -f ImageStream.yml
    $ oc create -f BuildConfig.yml
    
Use the OpenShift UI to add build variables: `RHSM_USERNAME`,
`RHSM_PASSWORD` and `RHSM_POOL` (these should really be managed as
secrets). Now...

    $ oc start-build satellite --follow
    $ oc create -f StatefulSet.yml

StatefulSet.yml is currently configured to request a 100Gi PV onto
which /etc and /var are stored.  NOTE: This container currently must
run root processes, and must be able to write files as root to the PV
(so, no root squashing for NFS exports).

Use the OpenShift UI to add a route
(`satellite-satellite.MY.OCP.ROUTER`). Make secure it (port 443), and
enable pass-through SSL.

The Satellite installation will continue the first time the container
is started.

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
handle in a Dockerfile style installation.

The answer here is to split the installation into two phases.  Phase
One is when we install all of the required RPMs.  This is done with a
simple Dockerfile that downloads all of the necessary RPMS.  Phase Two
is where we actually run the `satellite-install` process.  The trick
here is to use a systemd unit file to kick off the installation
process as a "one-shot" process.  Remember, our container is booting
into systemd because we need to start multiple services (postgresql,
etc).  


### Challenge 3: Managing state


### Challenge 4: Certificate handling


