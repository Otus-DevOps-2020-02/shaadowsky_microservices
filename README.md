# shaadowsky_microservices
shaadowsky microservices repository

## Введение в мониторинг.

### план

• Prometheus: запуск, конфигурация, знакомство с Web UI
• Мониторинг состояния микросервисов
• Сбор метрик хоста с использованием экспортера

### подготовка окружения

Создадим правило фаервола для Prometheus и Puma:

```
$ gcloud compute firewall-rules create prometheus-default --allow tcp:9090
$ gcloud compute firewall-rules create puma-default --allow tcp:9292
```

Создадим Docker хост в GCE и настроим локальное окружение на работу с ним

```
$ export GOOGLE_PROJECT=_ваш-проект_
# create docker host
$ docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host

# configure local env
$ eval $(docker-machine env docker-host)

$ docker run --rm -p 9090:9090 -d --name prometheus  prom/prometheus
$ docker-machine ip docker-host
```

по адресу докерхоста на порту 9090 будет доступен прометей.

```
$ docker stop prometheus
```

До перехода к следующему шагу приведем структуру каталогов в более четкий/удобный вид:
1. Создадим директорию docker в корне репозитория и перенесем в нее директорию docker-monolith и файлы docker-compose.* и все .env (.env должен быть в .gitgnore), в репозиторий закоммичен .env.example, из которого создается .env
2. Создадим в корне репозитория директорию monitoring. В ней будет хранится все, что относится к мониторингу
3. Не забываем про .gitgnore и актуализируем записи при необходимости

P.S. С этого момента сборка сервисов отделена от  docker-compose, поэтому инструкции build можно удалить из docker-compose.yml.

Создайте директорию _monitoring/prometheus_ c Dockerfile, который будет копировать файл конфигурации с локальной машины внутрь контейнера

```
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
```

Вся конфигурация Prometheus, в отличие от многих других систем мониторинга, происходит через файлы конфигурации и опции командной строки. Определим простой конфигурационный файл для сбора метрик с наших микросервисов. В директории monitoring/prometheus создайте файл prometheus.yml со следующим содержимым:

```
---
global:
  scrape_interval: '5s'   # частота сбора метрик

scrape_configs:
  - job_name: 'prometheus'  # Джобы объединяют в группы (endpoint-ы), выполняющие одинаковую функцию
    static_configs:
      - targets:
        - 'localhost:9090'  # адрес сбора метрик (endpoint)

  - job_name: 'ui'
    static_configs:
      - targets:
        - 'ui:9292'

  - job_name: 'comment'
    static_configs:
      - targets:
        - 'comment:9292'
```

В директории prometheus собираем Docker образ:
$ export USER_NAME=username
$ docker build -t $USER_NAME/prometheus .
Где USER_NAME - ВАШ логин от DockerHub. 

В коде микросервисов есть healthcheck-и для
проверки работоспособности приложения.
Сборку образов теперь необходимо производить
при помощи скриптов docker_build.sh, которые есть
в директории каждого сервиса. С его помощью мы
добавим информацию из Git в наш healthcheck. 

Выполните сборку образов при помощи скриптов docker_build.sh в директории каждого сервиса.

```
/src/ui $ bash docker_build.sh
/src/post-py $ bash docker_build.sh
/src/comment $ bash docker_build.sh
```

Или сразу все из корня репозитория:

```
for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done
```

Будем поднимать наш Prometheus совместно с микросервисами. Определите в вашем docker/docker-compose.yml файле новый сервис:

```
services:
...
  prometheus:
    image: ${USERNAME}/prometheus
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d'   # передаем доп. параметры в командной строке и задаем время хранения метрик в 1 день

volumes:
  prometheus_data:
```

так как прометею надо общаться со всеми микросервисами, добавим секцию networks:

```
    networks:
      - back_net
      - front_net
```

Поднимем сервисы, определенные в docker/dockercompose.yml

```
$ docker-compose up -d
```

Проверьте, что приложение работает и Prometheus запустился.

Посмотрим список endpoint-ов, с которых собирает
информацию Prometheus. Помните, что помимо самого
Prometheus, мы определили в конфигурации мониторинг ui и
comment сервисов. Endpoint-ы должны быть в состоянии UP. 

#### Healthchecks

Healthcheck-и представляют собой проверки того, что
наш сервис здоров и работает в ожидаемом режиме. В
нашем случае healthcheck выполняется внутри кода
микросервиса и выполняет проверку того, что все
сервисы, от которых зависит его работа, ему доступны.
Если требуемые для его работы сервисы здоровы, то
healthcheck проверка возвращает status = 1, что
соответсвует тому, что сам сервис здоров.
Если один из нужных ему сервисов нездоров или
недоступен, то проверка вернет status = 0. 

