# syntax=docker/dockerfile:1

FROM tomcat:9-jdk11-temurin-jammy

RUN apt-get update -y && apt-get upgrade -y \
	&& apt-get install -y \
	aapt \
	wget \
	sed \
	postgresql-client \
	&& rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/local/tomcat/conf/Catalina/localhost \
    && mkdir -p /usr/local/tomcat/ssl

# Set to 1 to force updating the config files
# If not set, they will be created only if there's no files
#ENV FORCE_RECONFIGURE=true

#ENV ADMIN_EMAIL=

ENV HMDM_VARIANT=os

# Available values of INSTALL_LANGUAGE: en, ru (en by default)
# value of SHARED_SECRET should be different for open source and premium versions!
ENV	INSTALL_LANGUAGE=en \
	SHARED_SECRET=changeme-C3z9vi54 \
	DOWNLOAD_CREDENTIALS= \
	HMDM_URL=https://h-mdm.com/files/hmdm-5.27.1-$HMDM_VARIANT.war \
	CLIENT_VERSION=5.27 \
	SQL_HOST=localhost \
	SQL_PORT=5432 \
	SQL_BASE=hmdm \
	SQL_USER=hmdm \
	SQL_PASS=Ch@nGeMe \
	SMTP_HOST=smtp.office365.com \
	SMTP_PORT=587 \
	SMTP_SSL=0 \
	SMTP_STARTTLS=1 \
	SMTP_FROM=cinfo@example.com \
	SMTP_USERNAME=cinfo@example.com \
	SMTP_PASSWORD=changeme \
	SMTP-SSL_VER=TLSv1.2 \
	PROTOCOL=https

#ENV BASE_DOMAIN=your-domain.com

# Set this parameter to your local IP address 
# if your server is behind the NAT
#ENV LOCAL_IP=172.31.91.82

# Comment it to use custom certificates
ENV HTTPS_LETSENCRYPT=true
# Mount the custom certificate path if custom certificates must be used
# ENV_HTTPS_CERT_PATH is the path to certificates and keys inside the container
#ENV HTTPS_CERT_PATH=/cert
ENV HTTPS_CERT=cert.pem
ENV HTTPS_FULLCHAIN=fullchain.pem
ENV HTTPS_PRIVKEY=privkey.pem

EXPOSE 8080 \
	   8443 \
	   31000

COPY docker-entrypoint.sh /
COPY tomcat_conf/server.xml /usr/local/tomcat/conf/server.xml 
ADD templates /opt/hmdm/templates/

ENTRYPOINT ["/docker-entrypoint.sh"]
