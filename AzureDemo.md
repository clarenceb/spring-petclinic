# Java on Azure

## Spring Pet Clinic

* Original repo: https://github.com/spring-projects/spring-petclinic
* More info on application: http://projects.spring.io/spring-petclinic/
* This fork: https://github.com/clarenceb/spring-petclinic

Open a terminal and clone the repo:

```sh
git clone https://github.com/clarenceb/spring-petclinic
cd spring-petclinic
```

### Run app locally with HSQL

```sh
./mvnw package
java -jar target/*.jar
```

or 

```sh
./mvnw spring-boot:run
```

Access web site: http://localhost:8080/

Note: This uses an in-memory DB (HSQLDB) with the default profile.

### Run app locally with MySQL

Ensure you have a [MySQL installation](https://dev.mysql.com/downloads/mysql/) locally.

Start MySQL:

```sh
# Ubuntu
sudo service mysql start

# If you are on WSL, set your timezone
sudo dpkg-reconfigure tzdata
```

Create database, user and grants:

```sh
mysql -uroot -p

mysql> CREATE DATABASE petclinic;
mysql> GRANT ALL PRIVILEGES ON petclinic.* TO 'petclinic'@'localhost' IDENTIFIED BY 'petclinic';
mysql> FLUSH PRIVILEGES;
mysql> exit;
```

Create schema and load intiital data:

```sh
mysql -uroot -Dpetclinic -p < src/main/resources/db/mysql/schema.sql
mysql -upetclinic -Dpetclinic -p < src/main/resources/db/mysql/data.sql
```

Start the app with the MySQL profile:

```sh
java -Dspring.profiles.active=mysql -jar target/*.jar
```

Access web site: http://localhost:8080/

To stop the app press `CTRL+C` in the terminal.

Stop MySQL to avoid interferring with the Docker MySQL in next step.

```sh
# Ubuntu
sudo service mysql stop
```

### Run as Docker containers locally

#### Standlone JAR (embedded Tomcat server)

Build the application container image:

```sh
docker build -t spring-petclinic -f Dockerfile.dev .
```

Start the application and mysql cointainers via `docker-compose`:

```sh
docker-compose up -d
docker-compose logs -f
# Wait for DB to be ready...
# Create schema and load initial data
mysql --protocol tcp -uroot -Dpetclinic -p < src/main/resources/db/mysql/schema.sql
mysql --protocol tcp -upetclinic -Dpetclinic -p < src/main/resources/db/mysql/data.sql
```

Access web site: http://localhost:8080/

Stop the containers: `CTRL+C`

Clean up container resources:

```sh
docker-compose down
```

### Run as Docker containers on Azure Kubernetes Service (AKS)

#### Create a common resource group for the resources

```sh
az group create --name aks-demos --location australiaeast
```

#### Create a Azure Container Registry (ACR)

```sh
az acr create --resource-group aks-demos --name aksdemos --sku Basic
az acr login --name aksdemos
#==> Login Succeeded
```

#### Tag and push the Docker image to ACR

*If you have limited upload bandwidth, follow steps in **Remote build and tag with ACR build** instead*

```sh
az acr list --resource-group aks-demos --query "[].{acrLoginServer:loginServer}" --output table
#==> AcrLoginServer
#==> -------------------
#==> aksdemos.azurecr.io
```

```sh
docker tag spring-petclinic:latest aksdemos.azurecr.io/spring-petclinic:v1
docker images
#==> REPOSITORY                            TAG     IMAGE ID      ...
#==> aksdemos.azurecr.io/spring-petclinic  v1      b0ed077cb2b2  ...
#==> spring-petclinic                      latest  b0ed077cb2b2  ...
```

```sh
docker push aksdemos.azurecr.io/spring-petclinic:v1
```

#### Remote build and tag with ACR build

*Use this method to avoid uploading image layers and utilise ACR to build the image for you using a multi-stage Docker build*

```
az acr build --registry aksdemos --resource-group aks-demos --image aksdemos.azurecr.io/spring-petclinic:v1 https://github.com/clarenceb/spring-petclinic.git
```

#### Verify Docker repository and tags

```sh
az acr repository list --name aksdemos --output table
az acr repository show-tags --name aksdemos --repository spring-petclinic --output table
```

#### Create a cluster

```sh
az ad sp create-for-rbac -n aks-demos --skip-assignment
```
