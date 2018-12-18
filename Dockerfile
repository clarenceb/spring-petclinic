## Multi-stage build
## =================

# Build stage (maven tools, JDK8, etc.)
# -------------------------------------
FROM maven:3.6-jdk-8-alpine as build

COPY src /usr/src/app/src
COPY pom.xml /usr/src/app
COPY sonar-project.properties /usr/src/app

RUN mvn -f /usr/src/app/pom.xml clean package

# Final stage (runtime distribution)
# -------------------------------------
FROM openjdk:8-jdk-alpine

# Add Maintainer Info
LABEL maintainer="demouser@example.com"

# Make port 8080 available to the world outside this container
EXPOSE 8080

# The application's jar file
ARG JAR_FILE=/usr/src/app/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar

# Database
ENV DB_HOST=localhost

# Add the application's jar to the container
COPY --from=build ${JAR_FILE} /app.jar

# Run the jar file
# (Avoid JVM delays caused by random number generation)
# ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-Dspring.profiles.active=mysql","-Dspring.datasource.url=jdbc:mysql://$DB_HOST/petclinic","-jar","/app.jar"]

# Workaround for DB not ready in time for app - your code should handle this!
ENTRYPOINT until nc -z $DB_HOST 3306; do sleep 1; echo "Waiting for DB to come up..."; done && java -Djava.security.egd=file:/dev/./urandom -Dspring.profiles.active=mysql -Dspring.datasource.url=jdbc:mysql://$DB_HOST/petclinic -jar /app.jar
