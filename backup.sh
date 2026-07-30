#!/bin/sh
cd "$(dirname "$0")"/world

CURRENT_DATE=$(date +"%Y-%m-%d_%H-%M")

git branch -M $CURRENT_DATE
git add ./world
git commit -m "Авто-бэкап мира: $CURRENT_DATE"
