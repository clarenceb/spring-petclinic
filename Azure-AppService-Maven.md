# Azure AppService Deployment via Maven Plugin

## Overview

Builds a WAR file for the SpringBoot PetClinic app and deploys to Azure App Services running Tomcat and JRE8 on Linux.

## Prerequisites

* Install the Azure CLI 2.0

You'll need an Azure subscription and you must have configured your credentials by logging in:

```sh
az login
```

Create a resource group:

```sh
az group create -n [resource-group-placeholder] -l [region-placeholder]
```

## Update the Maven POM file

Edit the Maven `pom.xml` file and fill in the Azure App Service info:

```xml
<!-- Web App information -->
<resourceGroup>[resource-group-placeholder]</resourceGroup>
<appName>[app-name-placeholder]</appName>
<region>[region-placeholder]</region>
<pricingTier>S1</pricingTier>
```

## Deploy to Azure App Services

Build, package and deploy the app:

```sh
mvn clean package azure-webapp:deploy
```

Access the app via the returned URL, i.e. `https://[appname].azurewebsites.net`

e.g. 

## Test web app locally

Download Tomcat for your OS from https://tomcat.apache.org/download-80.cgi

E.g. For Linux:

```sh
wget http://mirror.ventraip.net.au/apache/tomcat/tomcat-8/v8.5.32/bin/apache-tomcat-8.5.32.tar.gz
```

Unpack to a directory:

```sh
tar xzvf apache-tomcat-8.5.32.tar.gz
```

Copy the WAR file to the Tomcat `webapps` directory:

```sh
cp target/spring-petclinic.war apache-tomcat-8.5.32/webapps/
```

Start Tomcat:

```sh
./apache-tomcat-8.5.32/startup.sh
```

Browse to the web app: http://localhost:8080/spring-petclinic

Stop Tomcat:

```sh
./apache-tomcat-8.5.32/shutdown.sh
```


