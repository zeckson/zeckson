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

### Show which container uses `<volume>`
```shell
docker ps -a --filter volume=<volume>
```

### List all image `<image>` volumes 
```shell
docker inspect --format='{{.Config.Volumes}}' <image>
```

### Attach to running container `<name>`
```shell
docker container exec -it <name> /bin/bash
```
