#!/bin/sh
cd /usr/local/app/world

CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")

git branch -M $CURRENT_DATE
git add .
git commit -m "Авто-бэкап мира: $CURRENT_DATE"
