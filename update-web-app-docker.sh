#!/bin/bash
#
# Web application update script (headless for Docker)
TOMCAT_HOME=/usr/local/tomcat
TOMCAT_SERVICE=$(echo $TOMCAT_HOME | awk '{n=split($1,A,"/"); print A[n]}')
TOMCAT_USER=$(ls -ld $TOMCAT_HOME/webapps | awk '{print $3}')
FILES_DIRECTORY=$TOMCAT_HOME/work/files
WAR_FILE=$TOMCAT_HOME/webapps/ROOT.war
MANIFEST_FILE=$FILES_DIRECTORY/hmdm_web_update_manifest.txt

if [ ! -f $MANIFEST_FILE ]; then
    echo "No updates found. Select 'admin - Check for updates' in the web panel"
    exit 1
fi

NEW_WAR_FILE=$(cat $MANIFEST_FILE)

if [ ! -f $NEW_WAR_FILE ]; then
    echo "$NEW_WAR_FILE is not found."
    echo " Select 'admin - Check for updates - Get updates' in the web panel"
    exit 1
fi


echo "Version to install: $NEW_WAR_FILE"
echo "Destination: $WAR_FILE"

mv $NEW_WAR_FILE $WAR_FILE
chmod 644 $WAR_FILE
rm -f $MANIFEST_FILE

echo "Update successful. Please check the web panel version in 'admin - About'."
