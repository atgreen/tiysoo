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
