FROM ubuntu:latest
EXPOSE 25565

RUN apt-get update && apt-get install -y openjdk-21-jdk git wget

COPY req.txt ./

WORKDIR /usr/local/app/mods
RUN for line in $(cat ./req.txt); wget $(echo $line | cut -d "'" -f 2); end

WORKDIR /usr/local/app

RUN wget https://maven.neoforged.net/releases/net/neoforged/neoforge/21.1.217/neoforge-21.1.217-installer.jar
RUN java -jar neoforge-21.1.217-installer.jar --installServer
RUN echo "eula=true" >> eula.txt

CMD ["./run.sh"]
