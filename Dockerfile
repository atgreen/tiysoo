FROM registry.access.redhat.com/ubi7/ubi:latest

MAINTAINER Anthony Green <green@redhat.com>

# Sever the rhsm connection between this container and the host
RUN rm /etc/rhsm-host

# Register and attach to your satellite infrastructure pool
RUN subscription-manager register --username=$RHSM_USERNAME \
                                  --password=$RHSM_PASSWORD
RUN subscription-manager attach --pool=$RHSM_POOL

# Configure repos and install satellite RPMs
RUN subscription-manager repos --disable=\* \
    && for R in rhel-7-server-rpms rhel-server-rhscl-7-rpms \
             rhel-server-7-satellite-6-beta-rpms \
             rhel-7-server-satellite-maintenance-6-beta-rpms \
             rhel-7-server-ansible-2.6-rpms; do \
         subscription-manager repos --enable=$R; \
       done
RUN yum -y update && yum install -y satellite

# We wrap sysctl with a script to fake some of its answers to the
# installer.
RUN mv /usr/sbin/sysctl /usr/sbin/real-sysctl
COPY ./root/ /
RUN ln -s /etc/systemd/system/install-satellite.service /etc/systemd/system/default.target.wants/install-satellite.service

# Expose port 443
# We're going to use a pass-through secure route to OCP.
EXPOSE 443

CMD [ "/sbin/init" ]
