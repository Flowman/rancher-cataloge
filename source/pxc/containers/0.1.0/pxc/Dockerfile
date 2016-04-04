FROM debian:jessie

MAINTAINER Peter Szalatnay <theotherland@gmail.com>

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A \
    && echo 'deb http://repo.percona.com/apt jessie main' > /etc/apt/sources.list.d/percona.list

ENV PERCONA_MAJOR=5.6
ENV PERCONA_VERSION 5.6.28-25.14-1.jessie

RUN { \
        echo percona-xtradb-cluster-server-$PERCONA_MAJOR percona-xtradb-cluster-server/root_password password 'unused'; \
        echo percona-xtradb-cluster-server-$PERCONA_MAJOR percona-xtradb-cluster-server/root_password_again password 'unused'; \
    } | debconf-set-selections \
    && apt-get update && apt-get install -y \
        percona-xtradb-cluster-${PERCONA_MAJOR}=$PERCONA_VERSION \
        xinetd \
        curl \
        sysbench \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/mysql \
    && mkdir /var/lib/mysql

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
RUN sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf \
    && echo 'skip-host-cache\nskip-name-resolve' | awk '{ print } $1 == "[mysqld]" && c == 0 { c = 1; system("cat") }' /etc/mysql/my.cnf > /tmp/my.cnf \
    && mv /tmp/my.cnf /etc/mysql/my.cnf

RUN mkdir -p /opt/rancher \
    && curl -SL https://github.com/cloudnautique/giddyup/releses/download/v0.7.0/giddyup -o /opt/rancher/giddyup \
    && chmod +x /opt/rancher/giddyup \
    && echo "mysqlchk 9200/tcp #mysqlchk" >> /etc/services

COPY ./start_pxc /opt/rancher

COPY ./docker-entrypoint.sh /

VOLUME ["/var/lib/mysql", "/etc/mysql/conf.d"]

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 3306 4567 4568

CMD ["mysqld"]