FROM ubuntu:latest
EXPOSE 25565


RUN apt-get update && apt-get install -y openjdk-21-jdk git wget

# WORKDIR /usr/local/app/mods
#
# COPY req.txt ./
# RUN while IFS= read -r line; do wget $(echo "$line" | cut -d "'" -f 2); done < ./req.txt

WORKDIR /usr/local/app

COPY server.properties ./
ENV filename=forge-1.20.1-47.4.20-installer.jar

RUN wget https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.20/$filename
RUN java -jar $filename --installServer
RUN echo "eula=true" >> eula.txt

CMD ["./run.sh"]
