# shaadowsky_microservices
shaadowsky microservices repository


## Docker: сети, docker-compose

### изучаем
1. работа с сетями в Docker:
- none
- host
- bridge
2. использование docker-compose

### выполнение

Подключаемся к ранее созданному docker host’у

```
> docker-machine ls
NAME ACTIVE DRIVER STATE URL SWARM DOCKER
docker-host - google Running tcp://<docker-host-ip>:2376 v17.09.0-ce
> eval $(docker-machine env docker-host)
```

#### None network driver

Запустим контейнер с использованием none-драйвера.
В качестве образа используем joffotron/docker-net-tools
Делаем это для экономии сил и времени, т.к. в его состав уже
входят необходимые утилиты для работы с сетью: пакеты bindtools, net-tools и curl.
Контейнер запустится, выполнить команду `ifconfig` и будет
удален (флаг --rm)

```bash
$ docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig
Unable to find image 'joffotron/docker-net-tools:latest' locally
latest: Pulling from joffotron/docker-net-tools
3690ec4760f9: Pull complete 
0905b79e95dc: Pull complete 
Digest: sha256:5752abdc4351a75e9daec681c1a6babfec03b317b273fc56f953592e6218d5b5
Status: Downloaded newer image for joffotron/docker-net-tools:latest
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

В результате, видим:
• что внутри контейнера из сетевых интерфейсов
существует только loopback.
• сетевой стек самого контейнера работает (ping localhost),
но без возможности контактировать с внешним миром.
• Значит, можно даже запускать сетевые сервисы внутри
такого контейнера, но лишь для локальных
экспериментов (тестирование, контейнеры для
выполнения разовых задач и т.д.)

#### Host network driver

Запустим контейнер в сетевом пространстве docker-хоста

```bash
$  docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig 
docker0   Link encap:Ethernet  HWaddr 02:42:D5:87:40:E2  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:d5ff:fe87:40e2%32675/64 Scope:Link
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
...
ens4      Link encap:Ethernet  HWaddr 42:01:0A:84:00:03  
          inet addr:10.132.0.3  Bcast:10.132.0.3  Mask:255.255.255.255
          inet6 addr: fe80::4001:aff:fe84:3%32675/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1460  Metric:1
...
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1%32675/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
...

$  docker-machine ssh docker-host ifconfig
docker0   Link encap:Ethernet  HWaddr 02:42:d5:87:40:e2  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:d5ff:fe87:40e2/64 Scope:Link
          UP BROADCAST MULTICAST  MTU:1500  Metric:1
...
ens4      Link encap:Ethernet  HWaddr 42:01:0a:84:00:03  
          inet addr:10.132.0.3  Bcast:10.132.0.3  Mask:255.255.255.255
          inet6 addr: fe80::4001:aff:fe84:3/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1460  Metric:1
...
lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
...
```

как видно сетевые интерфейсы контейнера - это сетевые интерфейсы хоста, на котором находится контейнер.

Запустите несколько раз (2-4) _docker run --network host -d nginx_. 

```
[shaad@shaad-mobile src [docker-host]]$ docker ps
dockeCONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
318044a8bd0d        nginx               "nginx -g 'daemon of…"   37 seconds ago      Up 33 seconds                           eloquent_bhabha
797fbbb4b254        reddit:latest       "/start.sh"              11 days ago         Up 11 days                              reddit
[shaad@shaad-mobile src [docker-host]]$ docker ps -a
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                      PORTS               NAMES
7f797113a190        nginx               "nginx -g 'daemon of…"   24 seconds ago      Exited (1) 19 seconds ago                       condescending_babbage
cd7dffd01080        nginx               "nginx -g 'daemon of…"   26 seconds ago      Exited (1) 22 seconds ago                       condescending_cannon
6ae5b48a85f9        nginx               "nginx -g 'daemon of…"   31 seconds ago      Exited (1) 26 seconds ago                       charming_khayyam
318044a8bd0d        nginx               "nginx -g 'daemon of…"   40 seconds ago      Up 36 seconds                                   eloquent_bhabha
```

есть три лежащих нжинкса, они не могут запуститься, т.к. уже есть работающих нжинкс в этой сети.

Остановите все запущенные контейнеры: _docker kill $(docker ps -q)_

На docker-host машине выполните команду: _sudo ln -s /var/run/docker/netns /var/run/netns_. Теперь вы можете просматривать существующие в данный момент net-namespaces с помощью команды _sudo ip netns_

Повторите запуски контейнеров с использованием драйверов
none и host и посмотрите, как меняется список namespace-ов.
Примечание: ip netns exec <namespace> <command> - позволит выполнять
команды в выбранном namespace


### Bridge network driver

Создадим bridge-сеть в docker (флаг --driver указывать не
обязательно, т.к. по-умолчанию используется bridge) _docker network create reddit --driver bridge_

Запустим наш проект reddit с использованием bridge-сети

```
> docker run -d --network=reddit mongo:latest
> docker run -d --network=reddit <your-dockerhub-login>/post:1.0
> docker run -d --network=reddit <your-dockerhub-login>/comment:1.0
> docker run -d --network=reddit -p 9292:9292 <your-dockerhub-login>/ui:1.0 
```

оп, не работает, надо задавать сетевые алиасы

Решением проблемы будет присвоение контейнерам имен или
сетевых алиасов при старте:
--name <name> (можно задать только 1 имя)
--network-alias <alias-name> (можно задать множество алиасов)

Остановим старые копии контейнеров
> docker kill $(docker ps -q)
Запустим новые
> docker run -d --network=reddit --network-alias=post_db --networkalias=comment_db mongo:latest
> docker run -d --network=reddit --network-alias=post <your-login>/post:
1.0
> docker run -d --network=reddit --network-alias=comment <your-login>/
comment:1.0
> docker run -d --network=reddit -p 9292:9292 <your-login>/ui:1.0

работает

Теперь запустим проект в двух бридж сетях. Так, чтобы сервис ui не имел доступа к БД

Остановим старые копии контейнеров
> docker kill $(docker ps -q)
Создадим docker-сети
> docker network create back_net --subnet=10.0.2.0/24
> docker network create front_net --subnet=10.0.1.0/24

Запустим контейнеры
> docker run -d --network=front_net -p 9292:9292 --name ui <your-login>/ui:1.0
> docker run -d --network=back_net --name comment <your-login>/comment:1.0
> docker run -d --network=back_net --name post <your-login>/post:1.0
> docker run -d --network=back_net --name mongo_db \
 --network-alias=post_db --network-alias=comment_db mongo:latest 


 оп, не поднимается, 
 Docker при инициализации контейнера может подключить к нему только 1
сеть.
При этом контейнеры из соседних сетей не будут доступны как в DNS, так
и для взаимодействия по сети.
Поэтому нужно поместить контейнеры post и comment в обе сети.
Дополнительные сети подключаются командой:
> docker network connect <network> <container>

Подключим контейнеры ко второй сети
> docker network connect front_net post
> docker network connect front_net comment 

проверяем, Зайдем на адрес http://<your-machine>:9292 - работает.

Давайте посмотрим как выглядит сетевой стек Linux в
текущий момент, опираясь на схему из предыдущего
слайда:
1) Зайдите по ssh на docker-host и установите пакет bridge-utils
> docker-machine ssh docker-host
> sudo apt-get update && sudo apt-get install bridge-utils
2) Выполните:
> docker network ls
3) Найдите ID сетей, созданных в рамках проекта.
23
Избавляем бизнес от ИТ-зависимости
Bridge network driver
4) Выполните:
 > ifconfig | grep br
5) Найдите bridge-интерфейсы для каждой из сетей. Просмотрите
информацию о каждом.
6) Выберите любой из bridge-интерфейсов и выполните команду. Ниже
пример вывода:
 > brctl show <interface>
 bridge name bridge id STP enabled interfaces
 br-4ac81d1bf266 8000.0242ae9beade no vethaf41855
 vethe115d8d
Отображаемые veth-интерфейсы - это те части виртуальных пар
интерфейсов (2 на схеме), которые лежат в сетевом пространстве хоста и
также отображаются в ifconfig. Вторые их части лежат внутри контейнеров
24
Избавляем бизнес от ИТ-зависимости
Bridge network driver
7) Давайте посмотрим как выглядит iptables. Выполним:
> sudo iptables -nL -t nat (флаг -v даст чуть больше инфы)
Обратите внимание на цепочку POSTROUTING. В ней вы увидите нечто
подобное
Chain POSTROUTING (policy ACCEPT)
target prot opt source destination
MASQUERADE all -- 10.0.2.0/24 0.0.0.0/0
MASQUERADE all -- 172.18.0.0/16 0.0.0.0/0
MASQUERADE all -- 172.17.0.0/16 0.0.0.0/0
MASQUERADE tcp -- 172.18.0.2 172.18.0.2 tcp dpt:9292
Выделенные правила отвечают за выпуск во внешнюю сеть контейнеров из
bridge-сетей
25
Избавляем бизнес от ИТ-зависимости
Bridge network driver
8) В ходе работы у нас была необходимость публикации порта контейнера
UI (9292) для доступа к нему снаружи.
Давайте посмотрим, что Docker при этом сделал. Снова взгляните в iptables
на таблицу nat.
Обратите внимание на цепочку DOCKER и правила DNAT в ней. DNAT tcp -- 0.0.0.0/0 0.0.0.0/0 tcp dpt:9292 to:172.18.0.2:9292
Они отвечают за перенаправление трафика на адреса уже конкретных
контейнеров.
9) Также выполните:
> ps ax | grep docker-proxy
Вы должны увидеть хотя бы 1 запущенный процесс docker-proxy.
Этот процесс в данный момент слушает сетевой tcp-порт 9292.

### Docker-compose

Проблемы
• Одно приложение состоит из множества контейнеров/
сервисов
• Один контейнер зависит от другого
• Порядок запуска имеет значение
• docker build/run/create … (долго и много)

docker-compose
• Отдельная утилита
• Декларативное описание docker-инфраструктуры в YAMLформате
• Управление многоконтейнерными приложениями

План
• Установить docker-compose на локальную
машину
• Собрать образы приложения reddit с помощью
docker-compose
• Запустить приложение reddit с помощью dockercompose

создадим файл _./src/docker-compose.yml_ со следующим содержимым:

```code
version: '3.3'
services:
  post_db:
    image: mongo:3.2
    volumes:
      - post_db:/data/db
    networks:
      - reddit
  ui:
    build: ./ui
    image: ${USERNAME}/ui:1.0
    ports:
      - 9292:9292/tcp
    networks:
      - reddit
  post:
    build: ./post-py
    image: ${USERNAME}/post:1.0
    networks:
      - reddit
  comment:
    build: ./comment
    image: ${USERNAME}/comment:1.0
    networks:
      - reddit

volumes:
  post_db:

networks:
  reddit:
```

Отметим, что docker-compose поддерживает интерполяцию (подстановку) переменных окружения. В данном случае это переменная USERNAME. Поэтому перед запуском необходимо экспортировать значения данных переменных окружения, через .env-файл. В репозитории пример .env.example. Сам .env-файл надо добавлять в .gitignore, т.к. там может быть чувствительная информация

Остановим контейнеры, запущенные на предыдущих шагах
> docker kill $(docker ps -q)

Выполните:
> export USERNAME=<your-login>
> docker-compose up -d
> docker-compose ps
    Name                  Command             State           Ports         
----------------------------------------------------------------------------
src_comment_1   puma                          Up                            
src_post_1      python3 post_app.py           Up                            
src_post_db_1   docker-entrypoint.sh mongod   Up      27017/tcp             
src_ui_1        puma                          Up      0.0.0.0:9292->9292/tcp
```

Зайдите на http://<docker-machine-ip>:9292/ и убедитесь, что
проект работает ожидаемо корректно

Базовое имя проекта задается через переменную COMPOSE_PROJECT_NAME в .env-файле



### cheatsheet

форматируем вывод docker ps -a

```code
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Command}}\t {{.Status}}\t{{.Ports}}"
```

прибиваем контейнеры

```code
docker kill $(docker ps -q)
```
=======

## Docker-образы, микросервисы

### Цели задания

- научиться описывать и собирать Docker-образы для сервисного приложения
- научиться оптимизировать работу с Docker-образами
- запуск и работа приложения на основе docker-образов, оценка удобства запуска контейнеров при помощи _docker run_

### план

- разбить приложение на несколько компонентов
- запустить микросервисное приложение

### рекомендации

1. Для выполнения домашнего задания и дальнейшей работы с Docker-образами рекомендуется использовать линтер [hadolint](https://github.com/hadolint/hadolint)
2. Можно использовать линтер-плагины для IDE. В моем случае это плагины для VScode
3. Предоставленные примеры можно дополнять следуя обновлениям по документу рекомендуемых практик в написании [Dockerfile](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/#sort-multi-line-arguments)
4. Во всех образах, с которыми мы будем работать в этом задании, используются неоптимальные инструкции, обратите на это внимание и постарайтесь исправить их

### выполнение

подключить к ранее созданному докерхосту (см. [предыдущее ридми](readme/docker-2.md))

Подключаемся к ранее созданному Docker host’у (см. предыдущее ДЗ):

```bash
$ docker-machine ls
NAME          ACTIVE   DRIVER   STATE     URL                        SWARM   DOCKER     ERRORS
docker-host   -        google   Running   tcp://35.195.255.22:2376           v19.03.8   
```

Качаем архив с приложением, распаковываем, удаляем архив. Переименовить папку с приложением в _src_, котороая будет основной папкой данной ДЗ

Теперь наше приложение состоит из трех компонентов:
post-py - сервис отвечающий за написание постов
comment - сервис отвечающий за написание комментариев
ui - веб-интерфейс, работающий с другими сервисами

Для работы нашего приложения также требуется база данных MongoDB.

Создайте файл ./post-py/Dockerfile:

```code
FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN apk --no-cache --update add build-base && \
    pip install -r /app/requirements.txt && \
    apk del build-base

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
```

Создайте файл ./comment/Dockerfile:

```code
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV COMMENT_DATABASE_HOST comment_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
```

Создайте файл ./ui/Dockerfile:

```code
FROM ruby:2.2
RUN apt-get update -qq && apt-get install -y build-essential

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```

Скачаем последний образ MongoDB (в продакшн кейсах образы latest не рекомендуется использовать) и соберем образы со всеми сервисами:

```
docker pull mongo:latest
docker build -t <your-dockerhub-login>/post:1.0 ./post-py
docker build -t <your-dockerhub-login>/comment:1.0 ./comment
docker build -t <your-dockerhub-login>/ui:1.0 ./ui
```

Создадим специальную сеть (бридж) для приложения:

```
$ docker network create reddit
```

Запустим наши контейнеры, добавив им сетевые алиасы, которые будем использовать как доменные имена:

```
docker run -d --network=reddit \
--network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit \
--network-alias=post <your-dockerhub-login>/post:1.0
docker run -d --network=reddit \
--network-alias=comment <your-dockerhub-login>/comment:1.0
docker run -d --network=reddit \
-p 9292:9292 <your-dockerhub-login>/ui:1.0
```

Проверим:
- Зайдите на http://<docker-host-ip>:9292/
- Напишите пост
- Работает!

Попробуем запустить с другими алиасами, переопределив адреса для взаимодействия через ENV-переменные внутри Dockerfile'ов. Прибить контейнеры:

```
$ docker kill $(docker ps -q)
```

### ДОПИШУ ПОТОМ

### уменьшаем образа

Поменяем содержимое ./ui/Dockerfile

```code
FROM ubuntu:16.04
RUN apt-get update \
    && apt-get install -y ruby-full ruby-dev build-essential \
    && gem install bundler --no-ri --no-rdoc

ENV APP_HOME /app
RUN mkdir $APP_HOME

WORKDIR $APP_HOME
ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292

CMD ["puma"]
```

и пересоберём ui - _docker build -t <your-login>/ui:2.0 ./ui_, как видно, на основе образа убунту 1604, образ "весит" на 300 Мб меньше

```bash
$ docker images
REPOSITORY               TAG                 IMAGE ID            CREATED             SIZE
shaadowsky/ui            2.0                 3bb1b9f34cb9        7 seconds ago       461MB
shaadowsky/ui            1.0                 b862ab9aaebc        42 minutes ago      785MB
```

#### ДОДЕЛЫВАЕМ позже уменьшение образов

При остановке контейнера mongo данные пропали. Прокинем вольюм для MongoDB:

```
 docker volume create reddit_db
```

уберем старые контейнеры и запустим новые:

```
docker run -d --network=reddit --network-alias=post_db \
  --network-alias=comment_db -v reddit_db:/data/db mongo:latest
docker run -d --network=reddit \
  --network-alias=post <your-login>/post:1.0
docker run -d --network=reddit \
  --network-alias=comment <your-login>/comment:1.0
docker run -d --network=reddit \
  -p 9292:9292 <your-login>/ui:2.0
```

- Зайдите на http://<docker-host-ip>:9292/
- Напишите пост
- Перезапустите контейнеры
- Проверьте, что пост остался на месте
