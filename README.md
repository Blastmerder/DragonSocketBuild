## Header
- [Installation](#installation)
- [Run](#How_to_run)
- [Update](#update)
- [Stop](#How_to_stop)

## installation
```bash
docker pull ghcr.io/blastmerder/dragonsocketbuild:main
```

## How to run
```bash
docker compose --env-file .env.prod up -d
docker compose --env-file .env.prod logs -f minecraft
```

## How to update
```bash
docker compose --env-file .env.prod pull && docker compose --env-file .env.prod up -d
```

## How to stop
```bash
docker compose --env-file .env.prod down
```
