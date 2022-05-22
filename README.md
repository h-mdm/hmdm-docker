# Docker image for Headwind MDM

## Summary

The image is based on Ubuntu 20.04 and Tomcat 9.

It doesn't include PostgreSQL and certbot, so they need to be started in
separate containers or on the host machine.

## Building the image from the source code

Before building the image, review the default variables (in particular the 
Headwind MDM URL) in the Dockerfile and change them if required.

The build command is:

    docker build -t headwind/hmdm:1.0 .

## Prerequisites

1. Create the PostgreSQL database for Headwind MDM, and use the environment
variables SQL_HOST, SQL_BASE, SQL_USER, SQL_PASS to define the database access
credentials.

Default values are: SQL_HOST=localhost, SQL_BASE=hmdm, SQL_USER=hmdm,
SQL_PASS=topsecret

2. If you want to use HTTPS, install certbot and generate the certificate for
the domain where Headwind MDM should be installed.

    certbot certonly --standalone --force-renewal -d your-mdm-domain.com 

## Running the Docker container

** Please set up your domain name when running Headwind MDM! **

To create the container, use the command:

    docker run --network="host" -d -e BASE_DOMAIN=build.h-mdm.com -v /etc/letsencrypt:/etc/letsencrypt --name="hmdm" headwind/hmdm:1.0

If everything is fine, Headwind MDM will become available via the url 
https://your-mdm-domain.com:8443 in a few seconds. 

Also, http://your-mdm-domain.com:8080 is available by default.

Notice: --network="host" is defined to connect to the PostgreSQL database 
installed on the host machine.

To view logs, use the command:

    docker logs hmdm

Stop and start the container:

    docker stop hmdm
    docker start hmdm

Connect to the container for debugging:

    docker exec -it hmdm /bin/bash

## Configuration of Headwind MDM

The container is configured by the environment variables.

The full list of variables can be found in the Dockerfile.

## First start and subsequent starts

At first start, Headwind MDM performs the initialization:

  - Creates the config files using the environment
  - Initializes the database
  - Converts the LetsEncrypt's (or your own) SSL certificates to a JKS keystore

Subsequent starts of the container skip this step, but you can force the
configuration renewal by setting the following environment variable:

FORCE_RECONFIGURE=true

When this variable is set to true, the configuration is always re-created by the
Headwind MDM entry point script. 

