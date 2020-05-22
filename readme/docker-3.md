# shaadowsky_microservices
shaadowsky microservices repository

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







