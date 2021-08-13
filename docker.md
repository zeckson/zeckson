### Run bash on target container 

```shell script
docker run --rm --interactive --tty bash
```

### Run bash on target container and mount current dir to `/app` dir on volume

```shell script
docker run --rm --interactive --tty --volume $PWD:/app bash
```

### Build container with name `<name>`
```shell script
docker build -t <name> .
```
