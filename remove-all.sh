#!/bin/bash

echo "THIS SCRIPT WILL REMOVE ALL HEADWIND MDM DATA!"
echo "This may be useful for test purposes, "
echo "but never run this script on a production server!"
read -e -p "Type \"erase\" to delete all data: " RESPONSE
if [ "$RESPONSE" == "erase" ]; then
    echo "If you request LetsEncrypt keys 5 times within a week,"
    echo "you will be banned, so we don't recommend removing LetsEncrypt image"
    read -e -p "Remove LetsEncrypt volume as well [Y/n]?: " REMOVE_LETSENCRYPT

    docker-compose down --remove-orphans -v --rmi all
    rm -rf volumes/db
    rm -rf volumes/work
    if [[ "$REMOVE_LETSENCRYPT" =~ ^[Yy]$ ]]; then
        echo "Removing LetsEncrypt"
	rm -rf volumes/letsencrypt
    fi
    echo "All data has been removed"
else
    echo "Removal cancelled"
fi
