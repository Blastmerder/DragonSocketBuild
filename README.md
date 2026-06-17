# How to install and run

## installation
```bash
docker pull ghcr.io/blastmerder/dragonsocketbuild:main
```

## How to run
```bash
docker run -p 25565:25565 -v $(pwd)/world:/usr/local/app/world ghcr.io/blastmerder/dragonsocketbuild:main
```

If you on windows, you need to write your absolute path to world folder instade `$(pwd)/world`
