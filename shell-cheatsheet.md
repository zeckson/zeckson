### Print subdir disk usage:
```sh
du -sch *
```
#### Or use `ncdu`

#### Pack directory via tar.gz
```sh
tar -zcvf archive-name.tar.gz directory-name
```

#### Unpack drectory via tar.gz
```sh
tar -zxvf archive-name.tar.gz -C directory name
```
or to unpack in current dir:
```sh
tar -zxvf archive-name.tar.gz
```

#### Download file via SSH
```sh
scp username@hostname:/path/to/remote/file /path/to/local/file
```
or via cat:
```sh
ssh host 'cat /path/on/remote' > /path/on/local
 ```

#### Detect file type
```sh
file <path>
```

#### Apply permission for user:group recursively
```shell script
chown -R <user>:<group> <dir>
```

#### Curl send form

- To send form field
```shell script
curl -F'shorten=http://example.com/some/long/url' https://0x0.st
```

- To send file use `@` syntax:
```shell script
curl -F'file=@yourfile.png' https://0x0.st
```

#### Get the OS Version and Name
```shell script
uname -a
```

#### Write image to disk
```shell script
dd if=image.img of=/dev/diskNUMBER bs=1m
```

#### Create a soft-link to a target
```shell
ln -s <source> <target>
```
