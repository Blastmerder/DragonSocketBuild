FROM ubuntu:latest

RUN apt-get update && apt-get install -y openjdk-21-jdk git wget
ENV MEMORY=8G \
    EULA=false \
    RCON_PASSWORD=changeme \
    RCON_PORT=25575 \
    MC_PORT=25565 \
	SSH_KEY=changeme

# Копирование файла с задачами в директорию cron
COPY crontab /etc/cron.d/my-cron-jobs

# Настройка прав: владельцем должен быть root, права на чтение/запись — только у владельца
RUN chmod 0644 /etc/cron.d/my-cron-jobs

# Регистрация задач в системе
RUN crontab /etc/cron.d/my-cron-jobs

WORKDIR /usr/local/app/mods

COPY req.txt /tmp/req.txt
RUN wget -i /tmp/req.txt && rm -f /tmp/req.txt

WORKDIR /usr/local/app

COPY server.properties ./
COPY entrypoint.sh ./

ENV filename=forge-1.20.1-47.4.20-installer.jar

RUN wget https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.20/$filename
RUN java -jar $filename --installServer
RUN echo "eula=true" >> eula.txt

EXPOSE 25565 25575

CMD ["./entrypoint.sh"]
