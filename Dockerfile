FROM registry.access.redhat.com/ubi7/ubi:latest

MAINTAINER Anthony Green <green@redhat.com>

# Sever the rhsm connection between this container and the host
RUN rm /etc/rhsm-host

RUN echo export FOREMAN_ADMIN_PASSWORD=$FOREMAN_ADMIN_PASSWORD > /root/env.sh && \
    echo export APPLICATION_DOMAIN=$APPLICATION_DOMAIN >> /root/env.sh

# Register and attach to your satellite infrastructure pool
RUN subscription-manager register --username=$RHSM_USERNAME \
                                  --password=$RHSM_PASSWORD \
    && subscription-manager attach --pool=$RHSM_POOL \
    && subscription-manager repos --disable=\* \
    && for R in rhel-7-server-rpms rhel-server-rhscl-7-rpms \
             rhel-7-server-satellite-6.6-rpms \
             rhel-7-server-satellite-maintenance-6-rpms \
             rhel-7-server-ansible-2.6-rpms; do \
         subscription-manager repos --enable=$R; \
       done \
    && yum -y update \
    && yum install -y satellite postgresql-server \
       	   	      python-gofer-qpid ostree python-pulp-plugins \
		      puppet-agent-oauth puppetserver \
		      tfm-rubygem-foreman_openscap \
    && yum install -y /etc/foreman-installer/scenarios.d/satellite.yaml && ls -l /etc/foreman-installer/scenarios.d \
    && yum -y clean all \
    && rpm -qa | xargs -n1 rpm -V || true

# We wrap sysctl with a script to fake some of its answers to the
# installer.
RUN mv /usr/sbin/sysctl /usr/sbin/real-sysctl
COPY ./root/ /
RUN ln -s /etc/systemd/system/install-satellite.service /etc/systemd/system/default.target.wants/install-satellite.service

# Expose port 443
# We're going to use a pass-through secure route to OCP.
EXPOSE 443

CMD [ "/sbin/init" ]
