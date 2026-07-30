FROM ubuntu:latest

###################################################################
#                        Приготоволение                           #
###################################################################

RUN echo ===============Установка Пакетов===============

# Установка зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
							 openjdk-21-jdk-headless \
							 git \
							 wget \
							 cron \
							 tzdata \
							 ca-certificates
RUN rm -rf /var/lib/apt/lists/*

RUN echo ===============Копирование файлов===============
COPY crontab /etc/cron.d/my-cron-jobs

WORKDIR /usr/local/app/mods
COPY req.txt /tmp/req.txt

WORKDIR /usr/local/app
COPY server.properties backup.sh  entrypoint.sh ./

###################################################################
#                           Параметры                             #
###################################################################

ENV MEMORY=8G
ENV EULA=false
ENV RCON_PORT=25575
ENV MC_PORT=25565
ENV VOICE_PORT=24454

# Изменять при сборке проекта
ENV filename=forge-1.20.1-47.4.20-installer.jar

# Требуют изменений

ENV SSH_KEY=changeme
ENV RCON_PASSWORD=changeme

###################################################################
#                       Применение файлов                         #
###################################################################

RUN echo ===============Установка Модификаций и Создания cron job===============
# Загрузка модификаций
WORKDIR /usr/local/app/mods

RUN chmod 0644 /etc/cron.d/my-cron-jobs
RUN wget -i /tmp/req.txt && rm -f /tmp/req.txt

# Изменение правил для скриптов
WORKDIR /usr/local/app

RUN chmod +x ./entrypoint.sh backup.sh

###################################################################
#                            Запуск                               #
###################################################################

RUN echo ===============Инициализация Сервера===============

RUN wget https://maven.minecraftforge.net/net/minecraftforge/forge/1.20.1-47.4.20/$filename
RUN java -jar $filename --installServer
RUN echo "eula=true" >> eula.txt

EXPOSE ${MC_PORT} ${RCON_PORT} ${VOICE_PORT}/udp

CMD ["./entrypoint.sh"]

