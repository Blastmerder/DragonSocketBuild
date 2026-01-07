FROM ubuntu:latest

RUN apt-get update && apt-get install -y openjdk-21-jdk git wget

WORKDIR /usr/local/app

RUN wget https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.217/neoforge-21.1.217-installer.jar
RUN java -jar neoforge-21.1.217-installer.jar --installServer
RUN echo "eula=true" >> eula.txt
COPY req.txt ./
RUN mkdir mods && cd mods && for line in $(cat ./req.txt); wget $(echo $line | cut -d "'" -f 2); end
CMD ./run.sh
