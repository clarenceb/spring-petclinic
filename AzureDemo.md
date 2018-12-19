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

#### Prerequisites

* Azure Subscription
* Azure CLI installed
* Kubernetes CLI (kubectl) installed
* Helm CLI installed and Tiller installed in cluster

#### Create a common resource group for the resources

```sh
az group create --name aks-demos --location australiaeast
```

#### Create a Azure Container Registry (ACR)

```sh
az acr create --resource-group aks-demos --name aksdemos --sku Basic
az acr login --name aksdemos -g aks-demos
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

#### Setup an AKS cluster

```sh
# Configure ACR authentication for AKS cluster
az ad sp create-for-rbac --name http://aks-demos --skip-assignment
# Note down the appId and clientSecret for later
APP_ID=<appId>
CLIENT_SECRET=<clientSecret>
az acr show --resource-group aks-demos --name aksdemos --query "id" --output tsv
az role assignment create --assignee <appId> --scope <acrId> --role Reader
```

```sh
# Create the cluster
az aks create -n aksdemocluster -g aks-demos \
-k 1.11.4 \
--service-principal $APP_ID \
--client-secret $CLIENT_SECRET \
--generate-ssh-keys \
-l australiaeast \
--node-count 3 \
--enable-addons http_application_routing,monitoring

az aks list -o table

az aks get-credentials -n aksdemocluster -g aks-demos

kubectl get nodes
kubectl cluster-info
```

#### Create MySQL data for the service

From the Azure Portal, create a new resource of type `Azure Database for MySQL`.

Sample values:

* Server name: spring-petclinic
* Subscription: <your-subscription>
* Resource Group: aks-demos
* Server admin name: sadmin
* Password: <your-password>
* Location: Australia East
* Version: 5.7
* Pricing Tier: Basic

Note:

* This whole piece can be automated with ARM Templates, Terraform, etc.
* You could also use Open Service Broker for Azure to provision a database

Access the database resource in the portal.

Go to **Connection Security**

* Click 'Add client IP' so your machine can access the DB to load the schmema and data
* Enable 'Allow access to Azure services' for our app to work
* Click 'Save'

Go to **Connection strings**

* Copy the **JDBC** connection string

```
# JDBC connection string
jdbc:mysql://spring-petclinic.mysql.database.azure.com:3306/petclinic?useSSL=true&requireSSL=false
```

Create database, schema, initial data:

Create database, user and grants:

```sh
mysql --protocol tcp -h spring-petclinic.mysql.database.azure.com -u sadmin@spring-petclinic -p

mysql> CREATE DATABASE petclinic;
mysql> GRANT ALL PRIVILEGES ON petclinic.* TO 'sadmin'@'spring-petclinic' IDENTIFIED BY 'petclinic';
mysql> FLUSH PRIVILEGES;
mysql> exit;
```

```sh
mysql --protocol tcp -h spring-petclinic.mysql.database.azure.com -u sadmin@spring-petclinic -Dpetclinic -p < src/main/resources/db/mysql/schema.sql
mysql --protocol tcp -h spring-petclinic.mysql.database.azure.com -u sadmin@spring-petclinic -Dpetclinic -p < src/main/resources/db/mysql/data.sql
```

#### Create a database connection secrets

TODO: Update the spring properties / env var to use full connection string (Dockerfile too)

```sh
kubectl create secret generic petclinic-db-conn --from-literal="db_url=jdbc:mysql://spring-petclinic.mysql.database.azure.com:3306/petclinic?useSSL=true&requireSSL=false" --from-literal="db_user=sadmin@spring-petclinic" --from-literal="db_password=<your_password>"

kubectl describe secret petclinic-db-conn
```

#### Deploy app using db connection secret

```sh
kubectl apply -f kubernetes/spring-petclinic.deploy.yaml
kubectl get pod,deploy
```

The deployment manifest references the secret keys as enviornment variables in the container:

```yaml
...snip...
env:
- name: DB_URL
valueFrom:
    secretKeyRef:
    name: petclinic-db-conn
    key: db_url
```

#### Create a service to expose the app


#### Setup ingress controller

Since we use Helm, you'll need to install the Helm CLI and initialise Tiller in the cluster for RBAC.

```sh
helm install stable/nginx-ingress --namespace kube-system --set controller.replicaCount=2
kubectl get service -l app=nginx-ingress --namespace kube-system
# Note down the EXTERNAL-IP for later
```

Configure DNS name for the ingress endpoint:

```sh
./kubernetes/assign-ingress-dnsname.sh <external-api> <domain-name>
# e.g. ./kubernetes/assign-ingress-dnsname.sh 13.68.201.122 aksdemos
```

The ingress controller is now accessible through the FQDN: `<domain-name>.<region>.cloudapp.azure.com`

#### Create ingress resource

#### Set up TLS certs

#### Logging/Monitoring/Metrics

#### Rolling updates

TODO: push a v2 image with a change

#### Add readiness and healthcheck probes

#### Rolling updates, again...
