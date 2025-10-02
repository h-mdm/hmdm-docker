#!/bin/sh
HMDM_DIR=/opt/hmdm
TEMPLATE_DIR=$HMDM_DIR/templates
TOMCAT_DIR=/usr/local/tomcat
BASE_DIR=$TOMCAT_DIR/work
CACHE_DIR=$BASE_DIR/cache
PASSWORD=123456

# Normalize reverse proxy flag (true/false)
case "${REVERSE_PROXY:-false}" in
  [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|on) REVERSE_PROXY="true" ;;
  *) REVERSE_PROXY="false" ;;
esac

#handle reverse proxy setup
if [ "${REVERSE_PROXY:-false}" = "true" ]; then
    EFFECTIVE_PROTOCOL="https"
  echo "Replacing server.xml with reverse proxy friendly version..."
  if [ -f "$TEMPLATE_DIR/conf/rproxy_server.xml" ]; then
    cp "$TEMPLATE_DIR/conf/rproxy_server.xml" "$TOMCAT_DIR/conf/server.xml"
  else
    echo "WARN: reverse-proxy server.xml template not found at $TEMPLATE_DIR/conf/rproxy_server.xml" >&2
  fi
else
    EFFECTIVE_PROTOCOL="$PROTOCOL"
fi

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

$HMDM_DIR/update-web-app-docker.sh

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
    cat $TEMPLATE_DIR/conf/context_template.xml | sed "s|_SQL_HOST_|$SQL_HOST|g; s|_SQL_PORT_|$SQL_PORT|g; s|_SQL_BASE_|$SQL_BASE|g; s|_SQL_USER_|$SQL_USER|g; s|_SQL_PASS_|$SQL_PASS|g; s|_PROTOCOL_|$EFFECTIVE_PROTOCOL|g; s|_BASE_DOMAIN_|$BASE_DOMAIN|g; s|_SHARED_SECRET_|$SHARED_SECRET|g;" > $TOMCAT_DIR/conf/Catalina/localhost/ROOT.xml
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

cat $BASE_DIR/init1.sql | sed "s|https://h-mdm.com|$EFFECTIVE_PROTOCOL://$BASE_DOMAIN|g" > $BASE_DIR/init.sql
rm $BASE_DIR/init1.sql

cd $BASE_DIR/files
for FILE in $FILES_TO_DOWNLOAD; do
    FILENAME=$(basename $FILE)
    if [ ! -f "$BASE_DIR/files/$FILENAME" ]; then
	wget $FILE
    fi
done

if [ "$REVERSE_PROXY" = "true" ]; then
  echo "Reverse proxy setup enabled, skipping HTTPS setup."

else
  echo "Reverse proxy setup not enabled, proceeding with HTTPS setup if needed."

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