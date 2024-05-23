#!/bin/sh
HMDM_DIR=/opt/hmdm
TEMPLATE_DIR=$HMDM_DIR/templates
TOMCAT_DIR=/usr/local/tomcat
BASE_DIR=$TOMCAT_DIR/work
CACHE_DIR=$BASE_DIR/cache
PASSWORD=123456

for DIR in cache files plugins logs; do
   [ -d "$BASE_DIR/$DIR" ] || mkdir "$BASE_DIR/$DIR"
done

if [ ! -z "$LOCAL_IP" ]; then
    EXISTS=`grep $BASE_DOMAIN /etc/hosts`
    if [ -z "$EXISTS" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
        grep -v $BASE_DOMAIN /etc/hosts > /etc/hosts~
	cp /etc/hosts~ /etc/hosts
	echo "$LOCAL_IP $BASE_DOMAIN" >> /etc/hosts
	rm -f /etc/hosts~
    fi
fi

HMDM_WAR="$(basename -- $HMDM_URL)"

if [ ! -f "$CACHE_DIR/$HMDM_WAR" ]; then
    wget $DOWNLOAD_CREDENTIALS $HMDM_URL -O $CACHE_DIR/$HMDM_WAR
fi

if [ ! -f "$TOMCAT_DIR/webapps/ROOT.war" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cp $CACHE_DIR/$HMDM_WAR $TOMCAT_DIR/webapps/ROOT.war
fi

if [ ! -f "$BASE_DIR/log4j.xml" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cp $TEMPLATE_DIR/conf/log4j_template.xml $BASE_DIR/log4j-hmdm.xml
fi

if [ ! -d "$BASE_DIR/emails" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cp -r $TEMPLATE_DIR/emails $BASE_DIR/emails
fi

if [ ! -d $TOMCAT_DIR/conf/Catalina/localhost ]; then
    mkdir -p $TOMCAT_DIR/conf/Catalina/localhost
fi

if [ ! -f "$TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cat $TEMPLATE_DIR/conf/context_template.xml | sed "s|_SQL_HOST_|$SQL_HOST|g; s|_SQL_PORT_|$SQL_PORT|g; s|_SQL_BASE_|$SQL_BASE|g; s|_SQL_USER_|$SQL_USER|g; s|_SQL_PASS_|$SQL_PASS|g; s|_PROTOCOL_|$PROTOCOL|g; s|_BASE_DOMAIN_|$BASE_DOMAIN|g; s|_SHARED_SECRET_|$SHARED_SECRET|g;" > $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml 
fi

if { [ ! -z "$SMTP_HOST" ] && [ ! -z "$SMTP_USERNAME" ] && [ ! -z "$SMTP_PASSWORD" ]; } then
    sed -i "s|<!--    <Parameter name=\"smtp.host\" value=\"smtp.office365.com\"/>|    <Parameter name=\"smtp.host\" value=\"$SMTP_HOST\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    sed -i "s|<Parameter name=\"smtp.username\" value=\"info@example.com\"/>|<Parameter name=\"smtp.username\" value=\"$SMTP_USERNAME\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    sed -i "s|<Parameter name=\"smtp.password\" value=\"changeme\"/>|<Parameter name=\"smtp.password\" value=\"$SMTP_PASSWORD\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    if [ ! -z "$SMTP_FROM" ]; then
        sed -i "s|<Parameter name=\"smtp.from\" value=\"info@example.com\"/>  -->|<Parameter name=\"smtp.from\" value=\"$SMTP_FROM\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    else 
        sed -i "s|<Parameter name=\"smtp.from\" value=\"info@example.com\"/>  -->|<Parameter name=\"smtp.from\" value=\""$SMTP_USERNAME"\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    fi
    if [ ! -z "$SMTP_PORT" ] && [ "$SMTP_PORT" != "587" ]; then
        sed -i "s|<Parameter name=\"smtp.port\" value=\"587\"/>|<Parameter name=\"smtp.port\" value=\"$SMTP_PORT\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    fi
    if [ ! -z "$SMTP_SSL" ] && [ "$SMTP_SSL" != "0" ]; then
        sed -i "s|<Parameter name=\"smtp.ssl\" value=\"0\"/>|<Parameter name=\"smtp.ssl\" value=\"$SMTP_SSL\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    fi
    if [ ! -z "$SMTP_STARTTLS" ] && [ "$SMTP_STARTTLS" != "1" ]; then
        sed -i "s|<Parameter name=\"smtp.starttls\" value=\"1\"/>|<Parameter name=\"smtp.starttls\" value=\"$SMTP_STARTTLS\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
    fi
fi

if [ ! -z "$SMTP_SSL_VER" ]; then
    sed -i "s|<!-- <Parameter name=\"smtp.ssl.protocols\" value=\"TLSv1.2\"/> -->|<Parameter name=\"smtp.ssl.protocols\" value=\"$SMTP_SSL_VER\"/>|g" $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
fi

for DIR in cache files plugins logs; do
   [ -d "$BASE_DIR/$DIR" ] || mkdir "$BASE_DIR/$DIR"
done

if [ "$INSTALL_LANGUAGE" != "ru" ]; then
    INSTALL_LANGUAGE=en
fi

if [ ! -f "$BASE_DIR/init.sql" ] || [ "$FORCE_RECONFIGURE" = "true" ]; then
    cat $TEMPLATE_DIR/sql/hmdm_init.$INSTALL_LANGUAGE.sql | sed "s|_ADMIN_EMAIL_|$ADMIN_EMAIL|g; s|_HMDM_VERSION_|$CLIENT_VERSION|g; s|_HMDM_VARIANT_|$HMDM_VARIANT|g" > $BASE_DIR/init1.sql
fi

FILES_TO_DOWNLOAD=$(grep https://h-mdm.com $BASE_DIR/init1.sql | awk '{ print $4 }' | sed "s/'//g; s/)//g; s/,//g")

cat $BASE_DIR/init1.sql | sed "s|https://h-mdm.com|$PROTOCOL://$BASE_DOMAIN|g" > $BASE_DIR/init.sql
rm $BASE_DIR/init1.sql

cd $BASE_DIR/files
for FILE in $FILES_TO_DOWNLOAD; do
    FILENAME=$(basename $FILE)
    if [ ! -f "$BASE_DIR/files/$FILENAME" ]; then
	wget $FILE
    fi
done

# jks is always created from the certificates
if [ "$PROTOCOL" = "https" ]; then
    if [ "$HTTPS_LETSENCRYPT" = "true" ]; then
	HTTPS_CERT_PATH=/etc/letsencrypt/live/$BASE_DOMAIN
        echo "Looking for SSL keys in $HTTPS_CERT_PATH..."
	# If started by docker-compose, let's wait until certbot completes
	until [ -f $HTTPS_CERT_PATH/$HTTPS_PRIVKEY ]; do
            echo "Keys not found, waiting..."
	    sleep 5
        done
    fi

    openssl pkcs12 -export -out $TOMCAT_DIR/ssl/hmdm.p12 -inkey $HTTPS_CERT_PATH/$HTTPS_PRIVKEY -in $HTTPS_CERT_PATH/$HTTPS_CERT -certfile $HTTPS_CERT_PATH/$HTTPS_FULLCHAIN -password pass:$PASSWORD
    keytool -importkeystore -destkeystore $TOMCAT_DIR/ssl/hmdm.jks -srckeystore $TOMCAT_DIR/ssl/hmdm.p12 -srcstoretype PKCS12 -srcstorepass $PASSWORD -deststorepass $PASSWORD -noprompt    
fi

# Waiting for the database
until PGPASSWORD=$SQL_PASS psql -h "$SQL_HOST" -U "$SQL_USER" -d "$SQL_BASE" -c '\q'; do
  echo "Waiting for the PostgreSQL database..."
  sleep 5
done

# Avoid delays due to an issue with a random number
cp /opt/java/openjdk/conf/security/java.security /tmp/java.security
cat /tmp/java.security | sed "s|securerandom.source=file:/dev/random|securerandom.source=file:/dev/urandom|g" > /opt/java/openjdk/conf/security/java.security
rm /tmp/java.security

catalina.sh run

#sleep 100000
