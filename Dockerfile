# mssql-server-rhel
# Maintainers: Travis Wright (twright-msft on GitHub)
# GitRepo: https://github.com/twright-msft/mssql-server-rhel

# Base OS layer: latest RHEL 7
FROM registry.access.redhat.com/rhel7

### Atomic/OpenShift Labels - https://github.com/projectatomic/ContainerApplicationGenericLabels
LABEL name="microsoft/mssql-server-linux" \
      vendor="Microsoft" \
      version="14.0" \
      release="1" \
      summary="MS SQL Server" \
      description="MS SQL Server is ....." \
### Required labels above - recommended below
      url="https://www.microsoft.com/en-us/sql-server/" \
      run='docker run --name ${NAME} \
        -e ACCEPT_EULA=Y -e SA_PASSWORD=yourStrong@Password \
        -p 1433:1433 \
        -d  ${IMAGE}' \
      io.k8s.description="MS SQL Server is ....." \
      io.k8s.display-name="MS SQL Server" \
      maintainer="Michael Eichenberger mikeetpt@gmail.com"

### add licenses to this directory
COPY licenses /licenses

# Install latest mssql-server package
RUN REPOLIST=rhel-7-server-rpms,packages-microsoft-com-mssql-server-2017,packages-microsoft-com-prod,rhel-7-server-devtools-rpms && \
    curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/7/mssql-server-2017.repo && \
    curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/7/prod.repo && \
    ACCEPT_EULA=Y yum -y install --disablerepo "*" --enablerepo ${REPOLIST} --setopt=tsflags=nodocs \
    mssql-server mssql-tools unixODBC-devel krb5-workstation devtoolset-7-toolchain && \
    yum clean all

COPY uid_entrypoint /opt/mssql-tools/bin/
ENV PATH=${PATH}:/opt/mssql/bin:/opt/mssql-tools/bin
RUN mkdir -p /var/opt/mssql/data && \
    chmod -R g=u /var/opt/mssql /etc/passwd

# Copy krb5.conf file
COPY krb5.conf /etc

# Add keytab file
RUN mkdir /krb5 && \
    chown -R 10001:0 /krb5 && chmod -R og+rwx /krb5

# Copy odbcadd.txt file
COPY ./odbcadd.txt /home

# Register the SQL Server database DSN information in /etc/odbc.ini
RUN odbcinst -i -s -f /home/odbcadd.txt -l && \
    rm /home/odbcadd.txt

### Containers should not run as root as a good practice
USER 10001

# Default SQL Server TCP/Port
EXPOSE 1433

VOLUME /var/opt/mssql/data

### user name recognition at runtime w/ an arbitrary uid - for OpenShift deployments
# ENTRYPOINT [ "uid_entrypoint" ]
# Run SQL Server process
# CMD sqlservr
CMD scl enable devtoolset-7 'strace isql -v devapppbi'