# shaadowsky_microservices
shaadowsky microservices repository

устанавливаем [docker](https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/)

```bash
$ docker -v
Docker version 19.03.8, build afacb8b7f0
```

docker run -i = docker create + docker start + docker attach

docker run = docker create + docker start 

_docker create_ используется, когда не нужно стартовать контейнер сразу, в большинстве случаев используется _docker run_

Через параметры передаются лимиты(cpu/mem/disk), ip, volumes:
• -i – запускает контейнер в foreground режиме (docker attach)
• -d – запускает контейнер в background режиме
• -t создает TTY

_docker exec_:
• Запускает новый процесс внутри контейнера
• Например, bash внутри контейнера с приложением

_docker exec -it <u_container_id> bash_ 

_Docker commit_:
• Создает image из контейнера
• Контейнер при этом остается запущенным

 _docker commit <u_container_id> yourname/ubuntu-tmp-file_

Docker kill & stop:
• kill сразу посылает SIGKILL
• stop посылает SIGTERM, и через 10 секунд(настраивается) посылает SIGKILL
• SIGTERM - сигнал остановки приложения
• SIGKILL - безусловное завершение процесса

```bash
$ docker\ ps -q
8d0234c50f77
$ docker kill $(docker ps -q)
8d0234c50f77
```

_docker system df_
• Отображает сколько дискового пространства занято образами, контейнерами и volume’ами
• Отображает сколько из них не используется и возможно удалить

```bash
$  docker system df
TYPE                TOTAL               ACTIVE              SIZE                RECLAIMABLE
Images              12                  2                   728.2MB             725.2MB (99%)
Containers          2                   0                   2B                  2B (100%)
Local Volumes       594                 0                   11.69GB             11.69GB (100%)
Build Cache         0                   0                   0B                  0B
```

Docker rm & rmi
• rm удаляет контейнер, можно добавить флаг -f, чтобы удалялся работающий container(будет послан sigkill)
• rmi удаляет image, если от него не зависят запущенные контейнеры

```bash
$ docker rm $(docker ps -a -q) # удалит все незапущенные контейнеры
$ docker rmi $(docker images -q) # удалит все образа
```

создаем проект в gce, у меня это docker-276907

установим [gcloud SDK](https://cloud.google.com/sdk/). У меня уже установлено:

```bash
$ gcloud -v
Google Cloud SDK 291.0.0
alpha 2020.05.01
beta 2020.05.01
bq 2.0.57
core 2020.05.01
gsutil 4.50
kubectl 2020.05.01
```

выполняем в *_microservices/ _gcloud init_ и _gcloud auth application-default login_

устанавливаем [docker-machine](https://docs.docker.com/machine/install-machine/)

```bash
$ docker-machine version
docker-machine version 0.16.0, build 702c267f
```

• docker-machine - встроенный в докер инструмент для создания хостов и установки на них docker engine. Имеет поддержку облаков и систем виртуализации (Virtualbox, GCP и др.)
• Команда создания - docker-machine create <имя>. Имен может быть много, переключение между ними через eval $(docker-machine env <имя>). Переключение на локальный докер - _eval $(docker-machine env --unset)_. Удаление - _docker-machine rm <имя>_.
• docker-machine создает хост для докер демона со указываемым образом в --googlemachine-image, в ДЗ используется ubuntu-16.04. Образы которые используются для построения докер контейнеров к этому никак не относятся.
• Все докер команды, которые запускаются в той же консоли после _eval $(docker-machine env <имя>)_ работают с удаленным докер демоном в GCP.

Запускаем:

```bash
$ docker-machine create --driver google --google-project docker-276907 --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts --google-machine-type n1-standard-1 --google-zone europe-west1-b docker-host
Running pre-create checks...
...
Docker is up and running!
To see how to connect your Docker Client to the Docker Engine running on this virtual machine, run: docker-machine env docker-host

$  docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   -        google   Running   tcp://35.195.255.22:2376           v19.03.8   
$ eval $(docker-machine env docker-host)
```

Теперь когда у вас запущен докер хост в GCP, можете самостоятельно повторить демо из лекции посвященные:
• PID namespace (изоляция процессов)
• net namespace (изоляция сети)
• user namespaces (изоляция пользователей)

Для реализации Docker-in-Docker можно использовать этот [образ](https://github.com/jpetazzo/dind). Дока по [user namespace](https://docs.docker.com/engine/security/userns-remap/).

• docker run --rm -ti tehbilly/htop
• docker run --rm --pid host -ti tehbilly/htop

вторая команда запустит полноценный htop

Для дальнейшей работы нам потребуются четыре файла:
• Dockerfile - текстовое описание нашего образа
• mongod.conf - подготовленный конфиг для mongodb
• db_config - содержит переменную окружения со ссылкой на mongodb
• start.sh - скрипт запуска приложения

Вся работа происходит в папке docker-monolith

собираем образ:

```bash
$ docker build -t reddit:latest .
Sending build context to Docker daemon  7.168kB
Step 1/11 : FROM ubuntu:16.04
16.04: Pulling from library/ubuntu
...
Successfully built 08804c9c1642
Successfully tagged reddit:latest
```

• Точка в конце обязательна, она указывает на путь до Docker-контекста
• Флаг -t задает тег для собранного образа

Посмотрим на все образы (в том числе промежуточные):

```bash
$ docker images -a
REPOSITORY          TAG                 IMAGE ID            CREATED              SIZE
reddit              latest              08804c9c1642        About a minute ago   695MB
<none>              <none>              dae56acbff57        About a minute ago   695MB
<none>              <none>              59a0c92262b4        About a minute ago   695MB
<none>              <none>              c744db80d383        About a minute ago   648MB
<none>              <none>              e22ca46ea26c        About a minute ago   648MB
<none>              <none>              7d00dd3189e1        About a minute ago   648MB
<none>              <none>              59d2d9464a58        About a minute ago   648MB
<none>              <none>              36c94b41dd43        About a minute ago   647MB
<none>              <none>              e4cb9eec22b1        About a minute ago   644MB
<none>              <none>              7cb7420204ad        2 minutes ago        151MB
ubuntu              16.04               005d2078bdfa        2 weeks ago          125MB
tehbilly/htop       latest              4acd2b4de755        2 years ago          6.91MB
```

теперь можно запустить наш контейнер командой:

```bash
shaad@shaad-mobile:~/DevOps/shaadowsky_microservices/docker-monolith$ docker run --name reddit -d --network=host reddit:latest
797fbbb4b25493df5779b6c06b09f119e677cf51a062839fea89b44757acd303
shaad@shaad-mobile:~/DevOps/shaadowsky_microservices/docker-monolith$ docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   *        google   Running   tcp://35.195.255.22:2376           v19.03.8   
```

Откройте в браузере ссылку http://<ваш_IP_адрес>:9292

упс, недоступно, надо открыть порт:

```bash
$ gcloud compute firewall-rules create reddit-app \
 --allow tcp:9292 \
 --target-tags=docker-machine \
 --description="Allow PUMA connections" \
 --direction=INGRESS
```

### Docker Hub

Docker Hub - это облачный registry сервис от компании Docker. В него можно выгружать и загружать из него докер образы. Docker по умолчанию скачивает образы из докер хаба. 

Аутентифицируемся на docker hub для продолжения работы:

```bash
$ docker login
Authenticating with existing credentials...
Login Succeeded
```

Загрузим наш образ на docker hub для использования в будущем:

```bash
shaad@shaad-mobile:~/DevOps/shaadowsky_microservices/docker-monolith$ docker tag reddit:latest shaadowsky/otus-reddit:1.0
shaad@shaad-mobile:~/DevOps/shaadowsky_microservices/docker-monolith$ docker push shaadowsky/otus-reddit:1.0
The push refers to repository [docker.io/shaadowsky/otus-reddit]
c4f30bb6a3a8: Pushed 
....
b592b5433bbf: Mounted from library/ubuntu 
1.0: digest: sha256:e383de5c0b04551be2f4a4296a6c1cd273a930dc18129ed3848530f28dfa1ba6 size: 3035
```

Т.к. теперь наш образ есть в докер хабе, то мы можем запустить его не только в докер хосте в GCP, но и в вашем локальном докере или на другом хосте.
Выполним в другой консоли:

```bash
$ docker run --name reddit -d -p 9292:9292 shaadowsky/otus-reddit:1.0
Unable to find image 'shaadowsky/otus-reddit:1.0' locally
1.0: Pulling from shaadowsky/otus-reddit
e92ed755c008: Pull complete 
...
fa1ca2ab27c7: Pull complete 
Digest: sha256:e383de5c0b04551be2f4a4296a6c1cd273a930dc18129ed3848530f28dfa1ba6
Status: Downloaded newer image for shaadowsky/otus-reddit:1.0
a9d13c0d5328506b7f1e9d42af6e921e12c08e0eb2707d03ba6c7a26af655894
```

Дополнительно можете с помощью следующих команд изучить логи контейнера, зайти в выполняемый контейнер, посмотреть список процессов, вызвать остановку контейнера, запустить его повторно, остановить и удалить, запустить контейнер без запуска приложения и посмотреть процессы:
• docker logs reddit -f
• docker exec -it reddit bash
• ps aux
• killall5 1
• docker start reddit
• docker stop reddit && docker rm reddit
• docker run --name reddit --rm -it <your-login>/otus-reddit:1.0 bash
• ps aux
• exit

И с помощью следующих команд можно посмотреть подробную информацию о образе, вывести только определенный фрагмент информации, запустить приложение и добавить/удалить папки и посмотреть дифф, проверить что после остановки и удаления контейнера никаких изменений не останется:
• docker inspect <your-login>/otus-reddit:1.0
• docker inspect <your-login>/otus-reddit:1.0 -f '{{.ContainerConfig.Cmd}}'
• docker run --name reddit -d -p 9292:9292 <your-login>/otus-reddit:1.0
• docker exec -it reddit bash
• mkdir /test1234
• touch /test1234/testfile
• rmdir /opt
• exit
• docker diff reddit
• docker stop reddit && docker rm reddit
• docker run --name reddit --rm -it <your-login>/otus-reddit:1.0 bash
• ls /

docker build --no-cache на случай RUN apt-get -y update
