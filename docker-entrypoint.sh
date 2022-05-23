#!/bin/bash
HMDM_DIR=/opt/hmdm
TEMPLATE_DIR=/opt/hmdm/templates
TOMCAT_DIR=/usr/local/tomcat
BASE_DIR=/usr/local/tomcat/work
PASSWORD=123456

HMDM_WAR="$(basename -- $HMDM_URL)"

if [[ ! -f "$HMDM_DIR/$HMDM_WAR" ]]; then
    wget $HMDM_URL -O $HMDM_DIR/$HMDM_WAR
fi

if [[ ! -f "$TOMCAT_DIR/webapps/ROOT.war" ]] || [[ "$FORCE_RECONFIGURE" == "true" ]]; then
    cp $HMDM_DIR/$HMDM_WAR $TOMCAT_DIR/webapps/ROOT.war
fi

if [[ ! -f "$BASE_DIR/log4j.xml" ]] || [[ "$FORCE_RECONFIGURE" == "true" ]]; then
    cp $TEMPLATE_DIR/conf/log4j_template.xml $BASE_DIR/log4j-hmdm.xml
fi

if [ ! -d $TOMCAT_DIR/conf/Catalina/localhost ]; then
    mkdir -p $TOMCAT_DIR/conf/Catalina/localhost
fi

if [[ ! -f "$TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml" ]] || [[ "$FORCE_RECONFIGURE" == "true" ]]; then
    cat $TEMPLATE_DIR/conf/context_template.xml | sed "s|_SQL_HOST_|$SQL_HOST|g; s|_SQL_PORT_|$SQL_PORT|g; s|_SQL_BASE_|$SQL_BASE|g; s|_SQL_USER_|$SQL_USER|g; s|_SQL_PASS_|$SQL_PASS|g; s|_PROTOCOL_|$PROTOCOL|g; s|_BASE_DOMAIN_|$BASE_DOMAIN|g;" > $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml 
fi

if [ ! -d $BASE_DIR/files ]; then
    mkdir $BASE_DIR/files
fi

if [ ! -d $BASE_DIR/plugins ]; then
    mkdir $BASE_DIR/plugins
fi

if [ ! -d $BASE_DIR/logs ]; then
    mkdir $BASE_DIR/logs
fi

if [ "INSTALL_LANGUAGE" != "ru" ]; then
    INSTALL_LANGUAGE=en
fi

if [[ ! -f "$BASE_DIR/init.sql" ]] || [[ "$FORCE_RECONFIGURE" == "true" ]]; then
    cat $TEMPLATE_DIR/sql/hmdm_init.$INSTALL_LANGUAGE.sql | sed "s|_ADMIN_EMAIL_|$ADMIN_EMAIL|g; s|_HMDM_VERSION_|$CLIENT_VERSION|g; s|_HMDM_VARIANT_|$HMDM_VARIANT|g" > $BASE_DIR/init.sql
fi

# jks is always created from the certificates
if [[ "$PROTOCOL" == "https" ]]; then
    if [[ "$HTTPS_LETSENCRYPT" == "true" ]]; then
	HTTPS_CERT_PATH=/etc/letsencrypt/live/$BASE_DOMAIN
        # If started by docker-compose, let's wait until certbot completes
	until [[ -f $HTTPS_CERT_PATH/$HTTPS_PRIVKEY ]]; do
            echo "Waiting for the LetsEncrypt keys..."
	    sleep 5
        done
    fi

    openssl pkcs12 -export -out $TOMCAT_DIR/ssl/hmdm.p12 -inkey $HTTPS_CERT_PATH/$HTTPS_PRIVKEY -in $HTTPS_CERT_PATH/$HTTPS_CERT -certfile $HTTPS_CERT_PATH/$HTTPS_FULLCHAIN -password pass:$PASSWORD
    keytool -importkeystore -destkeystore $TOMCAT_DIR/ssl/hmdm.jks -srckeystore $TOMCAT_DIR/ssl/hmdm.p12 -srcstoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt    
fi

# Waiting for the database
until PGPASSWORD=$SQL_PASS psql -h "$SQL_HOST" -U "$SQL_USER" -c '\q'; do
  echo "Waiting for the PostgreSQL database..."
  sleep 5
done

catalina.sh run

#sleep 100000
