# Copyright © 2025 Devin B. Royal. All Rights Reserved.
FROM eclipse-temurin:17-jdk-jammy

WORKDIR /app
COPY pom.xml /app/
COPY src /app/src
RUN apt-get update && apt-get install -y maven
RUN mvn -q -DskipTests package
CMD ["java","-cp","target/nmar-core-0.2.0.jar","com.devin.nmar.App"]
