## Логирование и распреде распределенная трассировка

### План

- Сбор неструктурированных логов
- Визуализация логов
- Сбор структурированных логов
- Распределенная трасировка

### подготовка окружения

код проекта обновлен, забрать его по предоставленной ссылке и выполнить сборку образов при помощи скриптов docker_build.sh, выполнив из корня репозитория:

```
$ export USER_NAME=your_docker_username
$ for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done
```

Внимание! В данном ДЗ мы используем отдельные теги для контейнеров приложений :logging

1. Открывать порты в файрволле для новых сервисов нужно самостоятельно по мере их добавления.
2. Создадим Docker хост в GCE и настроим локальное окружение на работу с ним

```
$ export GOOGLE_PROJECT=_ваш-проект_

$ docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-open-port 5601/tcp \
    --google-open-port 9292/tcp \
    --google-open-port 9411/tcp \
    logging

# configure local env
$ eval $(docker-machine env logging)

# узнаем IP адрес
$ docker-machine ip logging
```

### Логирование Docker контейнеров

Elastic Stack
Как упоминалось на лекции хранить все логи стоит
централизованно: на одном (нескольких) серверах. В этом ДЗ мы
рассмотрим пример системы централизованного логирования на
примере Elastic стека (ранее известного как ELK): который включает
в себя 3 осовных компонента:
ElasticSearch (TSDB и поисковый движок для хранения данных)
Logstash (для агрегации и трансформации данных)
Kibana (для визуализации)
Однако для агрегации логов вместо Logstash мы будем
использовать Fluentd, таким образом получая еще одно
популярное сочетание этих инструментов, получившее название
EFK

Создадим отдельный compose-файл для нашей системы
логирования в папке docker/

```docker/docker-compose-logging.yml
version: '3'
services:
  fluentd:
    image: ${USERNAME}/fluentd
    ports:
      - "24224:24224"
      - "24224:24224/udp"

  elasticsearch:
    image: elasticsearch:7.4.0
    expose:
      - 9200
    ports:
      - "9200:9200"

  kibana:
    image: kibana:7.4.0
    ports:
      - "5601:5601"
```

создадим правила файрвола:

```
$ gcloud compute firewall-rules create kibana-default --allow tcp:5601
$ gcloud compute firewall-rules create elasticsearch-default --allow tcp:9200
$ gcloud compute firewall-rules create fluentd-default --allow tcp:24224 --allow udp:24224
```

Fluentd инструмент, который может использоваться для
отправки, агрегации и преобразования лог-сообщений. Мы будем
использовать Fluentd для агрегации (сбора в одной месте) и
парсинга логов сервисов нашего приложения.
Создадим образ Fluentd с нужной нам конфигурацией.
Создайте в вашем проекте microservices директорию
logging/fluentd
В созданной директорий, создайте простой Dockerfile со
следущим содержимым:

```
FROM fluent/fluentd:v0.12
RUN gem install fluent-plugin-elasticsearch --no-rdoc --no-ri --version 1.9.5
RUN gem install fluent-plugin-grok-parser --no-rdoc --no-ri --version 1.0.0
ADD fluent.conf /fluentd/etc
```

В директории logging/fluentd создайте файл конфигурации:

```
<source>
  @type forward   # Используем in_forward плагин для приема логов
                  # https://docs.fluentd.org/v0.12/articles/in_forward
  port 24224
  bind 0.0.0.0
</source>

<match *.**>
  @type copy      # Используем copy плагин, чтобы переправить все входящие логи в ElasticSearch, а также вывести в output
                  # https://docs.fluentd.org/v0.12/articles/out_copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```

Соберите docker image для fluentd
Из директории logging/fluentd
docker build -t $USER_NAME/fluentd .

### Структурированные логи

Логи должны иметь заданную (единую) структуру и содержать
необходимую для нормальной эксплуатации данного сервиса
информацию о его работе
Лог-сообщения также должны иметь понятный для выбранной
системы логирования формат, чтобы избежать ненужной траты
ресурсов на преобразование данных в нужный вид.
Структурированные логи мы рассмотрим на примере сервиса post

Правим .env файл и меняем теги нашего приложения на logging
Запустите сервисы приложения
docker/ $ docker-compose up -d

И выполните команду для просмотра логов post сервиса:

docker/ $ docker-compose logs -f post
Attaching to reddit_post_1

⚠ Внимание! Среди логов можно наблюдать проблемы с
доступностью Zipkin, у нас он пока что и правда не установлен.
Ошибки можно игнорировать.

Откройте приложение в браузере и создайте несколько постов,
пронаблюдайте, как пишутся логи post серсиса в терминале

post_1 | {"event": "find_all_posts", "level": "info", "message": "Successfully retrieved all posts from the database",
"params": {}, "request_id": "17501ae3-3d4f-4fe6-ac99-ca7cb58492a9", "service": "post", "timestamp": "2017-12-10 23:36:59"}
post_1 | {"addr": "172.21.0.7", "event": "request", "level": "info", "method": "GET", "path": "/posts?", "request_id":
"17501ae3-3d4f-4fe6-ac99-ca7cb58492a9", "response_status": 200, "service": "post", "timestamp": "2017-12-10 23:36:59"}
post_1 | {"event": "post_create", "level": "info", "message": "Successfully created a new post", "params": {"link":
"https://github.com/hynek/structlog", "title": "Structlog is awesome! "}, "request_id": "2aaf1ad3-42cf-4105-b585-d990eb22d85b",
"service": "post", "timestamp": "2017-12-10 23:37:18"}

Каждое событие, связанное с работой нашего приложения
логируется в JSON формате и имеет нужную нам структуру: тип
события (event), сообщение (message), переданные функции
параметры (params), имя сервиса (service) и др.

Как отмечалось на лекции, по умолчанию Docker контейнерами
используется json-file драйвер для логирования информации,
которая пишется сервисом внутри контейнера в stdout (и stderr).
Для отправки логов во Fluentd используем docker драйвер fluentd

Определим драйвер для логирования для сервиса post внутри
compose-файла

```docker/docker-compose.yml
version: '3'
services:
  post:
    image: ${USER_NAME}/post
    environment:
      - POST_DATABASE_HOST=post_db
      - POST_DATABASE=posts
    depends_on:
      - post_db
    ports:
      - "5000:5000"
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post
```

Сбор логов Post сервиса
Поднимем инфраструктуру централизованной системы
логирования и перезапустим сервисы приложения Из каталога
docker

$ docker-compose -f docker-compose-logging.yml up -d
$ docker-compose down
$ docker-compose up -d


Создадим несколько постов в приложении.

Kibana - инструмент для визуализации и анализа логов от
компании Elastic.
Откроем WEB-интерфейс Kibana для просмотра собранных в
ElasticSearch логов Post-сервиса (kibana слушает на порту 5601)

Добавим фильтр для парсинга json логов, приходящих от post
сервиса, в конфиг fluentd

```logging/fluentd/fluent.conf
<source>
@type forward
port 24224
bind 0.0.0.0
</source>
<filter service.post>
@type parser
format json
key_name log
</filter>
<match *.**>
@type copy
...
```

После этого персоберите образ и перезапустите сервис fluentd
logging/fluentd $ docker build -t $USER_NAME/fluentd
docker/ $ docker-compose -f docker-compose-logging.yml up -d fluentd

Создадим пару новых постов, чтобы проверить парсинг логов

Вновь обратимся к Kibana. Прежде чем смотреть логи убедимся,
что временной интервал выбран верно. Нажмите один раз на дату
со временем

### Неструктурированные
логи

Неструктурированные логи отличаются отсутствием четкой
структуры данных. Также часто бывает, что формат лог-сообщений
не подстроен под систему централизованного логирования, что
существенно увеличивает затраты вычислительных и временных
ресурсов на обработку данных и выделение нужной информации.
На примере сервиса ui мы рассмотрим пример логов с
неудобным форматом сообщений

По аналогии с post сервисом определим для ui сервиса драйвер
для логирования fluentd в compose-файле

```docker/docker-compose.yml
  ui:
    image: "${USER_NAME}/ui:$VER_UI"
    environment:
      - POST_SERVICE_HOST=post
      - POST_SERVICE_PORT=5000
      - COMMENT_SERVICE_HOST=comment
      - COMMENT_SERVICE_PORT=9292
    ports:
      - ${UI_PORT}:${REDDIT_PORT}/tcp
    depends_on:
      - post
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.ui
```

Перезапустим ui сервис Из каталога docker

$ docker-compose stop ui
$ docker-compose rm ui
$ docker-compose up -d

### Парсинг

Когда приложение или сервис не пишет структурированные
логи, приходится использовать старые добрые регулярные
выражения для их парсинга в /logging/fluentd/fluent.conf
Следующее регулярное выражение нужно, чтобы успешно
выделить интересующую нас информацию из лога UI-сервиса в
поля

```
source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<filter service.post>
  @type parser
  format json
  key_name log
</filter>

<filter service.ui>
  @type parser
  format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
  key_name log
</filter>


<match *.**>
  @type copy
  <store>
    @type elasticsearch
    host elasticsearch
    port 9200
    logstash_format true
    logstash_prefix fluentd
    logstash_dateformat %Y%m%d
    include_tag_key true
    type_name access_log
    tag_key @log_name
    flush_interval 1s
  </store>
  <store>
    @type stdout
  </store>
</match>
```

Созданные регулярки могут иметь ошибки, их сложно менять и
невозможно читать. Для облегчения задачи парсинга вместо
стандартных регулярок можно использовать grok-шаблоны. По-сути
grok’и - это именованные шаблоны регулярных выражений (очень
похоже на функции). Можно использовать готовый regexp, просто
сославшись на него как на функцию docker/fluentd/fluent.conf

```
<filter service.ui>
  @type parser
  format grok
  grok_pattern %{RUBY_LOGGER}
  key_name log
</filter>
```

Это grok-шаблон, зашитый в плагин для fluentd. В развернутом
виде он выглядит вот так:
%{RUBY_LOGGER} [(?<timestamp>(?>\d\d){1,2}-(?:0?[1-9]|1[0-2])-(?:(?:0[1-9])|(?:[12][0-9])|
(?:3[01])|[1-9])[T ](?:2[0123]|[01]?[0-9]):?(?:[0-5][0-9])(?::?(?:(?:[0-5]?[0-9]|60)(?:
[:.,][0-9]+)?))?(?:Z|[+-](?:2[0123]|[01]?[0-9])(?::?(?:[0-5][0-9])))?) #(?<pid>\b(?:[1-9]
[0-9]*)\b)\] *(?<loglevel>(?:DEBUG|FATAL|ERROR|WARN|INFO)) -- +(?<progname>.*?): (?
<message>.*)
```

Как было видно после предыдущего парсера - часть логов нужно еще
распарсить. Для этого используем несколько Grok-ов по-очереди

```
<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  key_name message
  reserve_data true
</filter>
```

