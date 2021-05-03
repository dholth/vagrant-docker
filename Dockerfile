# syntax=docker/dockerfile:1.0-experimental
# This repository demonstrates building a RPM cache in one stage of a build,
# then using the cache, without bloating the final image, in an another stage.

# It also demonstrates using docker with Vagrant's docker backend.

# Tested on Docker Engine 18.09
# To use, enable experimental features in your docker, and/or export DOCKER_BUILDKIT=1
# Then run `docker build .` as usual.

# See https://github.com/docker-library/docs/blob/master/centos/README.md
FROM centos:8 AS centos-with-init
ENV container docker
# the centos instructions were outdated. a nearly unmodified image works better.
CMD ["/usr/sbin/init"]


# A cache of RPMs that we can use in other stages of the build
FROM centos:8 AS yum-cache

# (add any other repositories you need here)

# RUN yum -y install deltarpm
# no deltarpm package in centos8
# dnf handles (or doesn't) deltarpm, differently
RUN yum -y install drpm

# (generate list in a model container with rpm -qa --qf "%{NAME}\n" | sort)
COPY ./packagelist.txt .

# Build cache of RPMs in packagelist.txt without installing
RUN yum -y install --downloadonly --skip-broken $(cat packagelist.txt)


FROM centos-with-init as vagrant-base
LABEL maintainer="Daniel Holth <dholth@gmail.com>"

RUN yum -y install passwd && useradd vagrant \
  && echo "vagrant" | passwd --stdin vagrant \
  && usermod -a -G wheel vagrant

# allow vagrant to login
RUN cd ~vagrant \
  && mkdir .ssh \
  && echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" > .ssh/authorized_keys \
  && chown -R vagrant:vagrant .ssh \
  && chmod 0700 .ssh \
  && chmod 0600 .ssh/authorized_keys

# install sudo, sshd, scp
RUN yum -y install sudo openssh-server openssh-clients; systemctl enable sshd.service

# From https://github.com/jdeathe/centos-ssh/blob/centos-7-develop/Dockerfile
# Provisioning
# - UTC Timezone
# - Networking (services expect this file)
# - Configure SSH defaults for non-root public key authentication
# - Enable the wheel sudoers group
# ------------------------------------------------------------------------------
RUN ln -sf \
    /usr/share/zoneinfo/UTC \
    /etc/localtime \
  && echo "NETWORKING=yes" \
    > /etc/sysconfig/network \
  && sed -i \
    -e 's~^#PermitRootLogin yes~PermitRootLogin no~g' \
    -e 's~^PasswordAuthentication yes~PasswordAuthentication no~g' \
    -e 's~^#UseDNS yes~UseDNS no~g' \
    /etc/ssh/sshd_config \
  && sed -i \
    -e 's~^# %wheel\tALL=(ALL)\tALL~%wheel\tALL=(ALL) ALL~g' \
    -e 's~\(.*\) requiretty$~#\1requiretty~' \
  /etc/sudoers \
  && echo "vagrant ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vagrant_user

# Disable annoying log messages (though they cannot be filtered from journalctl)
# RUN echo ":msg, contains, \"Time has been changed\" ~" > /etc/rsyslog.d/time_msgs.conf

EXPOSE 22

CMD ["/usr/sbin/init"]


# Install packages into our new container, using the cache
FROM vagrant-base AS vagrant-with-packages

# Normally you'd groupinstall or do your regular deployment instead of
# asking for a specific list of packages, but it would be fast because most of
# the packages are already in the cache container's /var/cache/yum
# CentOS/8 uses dnf
COPY ./packagelist.txt .
RUN --mount=target=/var/cache/dnf,source=/var/cache/dnf,from=yum-cache \
  yum -y install --skip-broken $(cat packagelist.txt) > yum.log 2>&1

# Docker's new --mount syntax keeps the yum cache out of our target container.

# If we weren't using new docker, we could use the COPY command to pull the yum cache
# into the target container, but the image would be (du -h /var/cache/yum) bigger.

# We store yum's output in yum.log only to prove that it used the cache.
# If these two lines are together, it means no packages were downloaded:

# Total size: 27 M
# Downloading packages:
# Running transaction check

# If yum had to download packages from the network, it will look more like:

# Total download size: 27 M
# Downloading packages:
# Delta RPMs disabled because /usr/bin/applydeltarpm not installed.
# --------------------------------------------------------------------------------
# Total                                              9.8 MB/s |  27 MB  00:02
# Running transaction check

# We might install more packages in our container, generate a new packagelist.txt,
# and then rebuild it many times without downloading the whole set of RPMs again.
