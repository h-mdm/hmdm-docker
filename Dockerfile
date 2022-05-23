# syntax=docker/dockerfile:1

FROM ubuntu:20.04
FROM tomcat:9.0.40

RUN apt-get update -y
RUN apt-get install -y \
	aapt \
	wget \
	sed \
        postgresql-client \
	&& rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/tomcat/conf/Catalina/localhost
RUN mkdir -p /usr/local/tomcat/ssl

# Set to 1 to force updating the config files
# If not set, they will be created only if there's no files
#ENV FORCE_RECONFIGURE=true

# Available values: en, ru (en by default)
ENV INSTALL_LANGUAGE=en

#ENV ADMIN_EMAIL=

ENV HMDM_VARIANT=os
ENV DOWNLOAD_CREDENTIALS=
ENV HMDM_URL=https://h-mdm.com/files/hmdm-5.06.3-$HMDM_VARIANT.war
ENV CLIENT_VERSION=5.04

ENV SQL_HOST=localhost
ENV SQL_PORT=5432
ENV SQL_BASE=hmdm
ENV SQL_USER=hmdm
ENV SQL_PASS=Ch@nGeMe

ENV PROTOCOL=https
#ENV BASE_DOMAIN=your-domain.com

# Comment it to use custom certificates
ENV HTTPS_LETSENCRYPT=true
# Mount the custom certificate path if custom certificates must be used
# ENV_HTTPS_CERT_PATH is the path to certificates and keys inside the container
#ENV HTTPS_CERT_PATH=/cert
ENV HTTPS_CERT=cert.pem
ENV HTTPS_FULLCHAIN=fullchain.pem
ENV HTTPS_PRIVKEY=privkey.pem

EXPOSE 8080
EXPOSE 8443
EXPOSE 31000

COPY docker-entrypoint.sh /
COPY tomcat_conf/server.xml /usr/local/tomcat/conf/server.xml 
ADD templates /opt/hmdm/templates

ENTRYPOINT ["/docker-entrypoint.sh"]
