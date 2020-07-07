# shaadowsky_microservices
shaadowsky microservices repository

## Мониторинг приложения и инфраструктуры

### план

- Мониторинг Docker контейнеров
- Визуализация метрик
- Сбор метрик работы приложения и бизнес метрик
- Настройка и проверка алертинга

### подготовка окружения

правила для файрвола создаются по мере необходимости по типу:

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

# Переключение на локальный докер
eval $(docker-machine env --unset)

$ docker-machine ip docker-host

$ docker-machine rm docker-host
```

### Мониторинг Docker контейнеров

Разделим файлы Docker Compose. В данный момент и мониторинг и приложения у нас описаны в одном большом docker-compose.yml. С одной стороны это просто, а с другой - мы смешиваем различные сущности, и сам файл быстро растет.

Оставим описание приложений в docker-compose.yml, а мониторинг выделим в отдельный файл docker-composemonitoring.yml. Для запуска приложений будем как и ранее использовать docker-compose up -d, а для мониторинга - docker-compose -f docker-compose-monitoring.yml up -d

Мы будем использовать для наблюдения за состоянием наших Docker контейнеров. cAdvisor собирает информацию о ресурсах потребляемых контейнерами и характеристиках их работы. Примерами метрик являются:
- процент использования контейнером CPU и памяти, выделенные для его запуска,
- объем сетевого трафика
- и др.

cAdvisor также будем запускать в контейнере. Для этого добавим новый сервис в наш компоуз файл мониторинга dockercompose-monitoring.yml. Поместите данный сервис в одну сеть с Prometheus, чтобы тот мог собирать с него метрики.

```
cadvisor:
  image: google/cadvisor:v0.29.0
  volumes:
    - '/:/rootfs:ro'
    - '/var/run:/var/run:rw'
    - '/sys:/sys:ro'
    - '/var/lib/docker/:/var/lib/docker:ro'
  ports:
    - '8080:8080'
```

Добавим информацию о новом сервисе в конфигурацию
Prometheus, чтобы он начал собирать метрики:
Пересоберем образ Prometheus с обновленной конфигурацией:

```
scrape_configs:
...
  - job_name: 'cadvisor'
    static_configs:
      - targets:
      - 'cadvisor:8080'
```

Пересоберем образ Prometheus с обновленной конфигурацией:

```
$ export USER_NAME=username # где username - ваш логин на Docker Hub
$ docker build -t $USER_NAME/prometheus .
```

откроем порт:

```
$ gcloud compute firewall-rules create cadvisor-default --allow tcp:8080
```

Запустим сервисы: 

```
$ docker-compose up -d
$ docker-compose -f docker-compose-monitoring.yml up -d
```

cAdvisor имеет UI, в котором отображается собираемая о контейнерах информация. Откроем страницу Web UI по адресу http://<docker-machinehost-ip>:8080

Нажмите ссылку Docker Containers (внизу слева) для просмотра информации по контейнерам. В UI мы можем увидеть: 
- список контейнеров, запущенных на хосте
- информацию о хосте (секция Driver Status)
- информацию об образах контейнеров (секция Images)

По пути /metrics все собираемые метрики публикуются для сбора Prometheus. Видим, что имена метрик контейнеров начинаются со слова container

Проверим, что метрики контейнеров собираются Prometheus (ip:9090). Введем, слово container и посмотрим, что он предложит дополнить:

### Визуализация метрик: Grafana

Используем инструмент Grafana для визуализации данных из Prometheus. Добавим новый сервис в docker-compose-monitoring.yml,

```
services:

  grafana:
    image: grafana/grafana:5.0.0
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secret
    depends_on:
      - prometheus
    ports:
      - 3000:3000

volumes:
  grafana_data:
```

Запустим новый сервис:

```
$ docker-compose -f docker-compose-monitoring.yml up -d grafana
```

добавим правило для графаны

```
$ gcloud compute firewall-rules create grafana-default --allow tcp:3000
```

Откроем страницу Web UI Grafana по адресу http://<dockermachine-host-ip>:3000 и используем для входа логин и пароль администратора, которые мы передали через переменные окружения (admin/secret)

Нажмем Add data source (Добавить источник данных). Зададим нужный тип и параметры подключения:
Name: Prometheus Server
Type: Prometheus
URL: http://prometheus:9090
Access: Proxy
И затем нажмем Add

Перейдем на сайт графаны, где можно найти и скачать большое количество уже созданных официальных и комьюнити дашбордов для визуализации различного типа метрик для разных систем мониторинга и баз данных. Выберем в качестве источника данных нашу систему мониторинга (Prometheus) и выполним поиск по категории Docker.

Затем выберем популярный дашборд Docker and system monitoring. Нажмем Загрузить JSON. В директории monitoring создайте директории grafana/dashboards, куда поместите скачанный дашборд. Поменяйте название файла дашборда на DockerMonitoring.json.

Снова откроем веб-интерфейс
Grafana и выберем импорт шаблона
(Import). Загрузите скачанный дашборд. При загрузке укажите источник данных для визуализации (Prometheus Server). Должен появиться набор графиков с информацией о состоянии хостовой системы и работе контейнер

Внесем метрики для сервиса UI:
- счетчик ui_request_count, который считает каждый приходящий HTTP-запрос (добавляя через лейблы такую информацию как HTTP метод, путь, код возврата, мы уточняем данную метрику)
- гистограмму ui_request_latency_seconds, которая позволяет отслеживать информацию о времени обработки каждого запроса

```src/ui/config.ru
+ require './middleware.rb'

+ use Metrics
```

```src/ui/middleware.rb
require 'prometheus/client'

class Metrics

  def initialize app
    @app = app
    prometheus = Prometheus::Client.registry
    @request_count = Prometheus::Client::Counter.new(:ui_request_count, 'App Request Count')
    @request_latency = Prometheus::Client::Histogram.new(:ui_request_latency_seconds, 'Request latency')
    prometheus.register(@request_latency)
    prometheus.register(@request_count)
  end

  def call env
    request_started_on = Time.now
    @status, @headers, @response = @app.call(env)
    request_ended_on = Time.now
    @request_latency.observe({ path: env['REQUEST_PATH'] }, request_ended_on - request_started_on)
    @request_count.increment({ method: env['REQUEST_METHOD'], path: env['REQUEST_PATH'], http_status: @status })
    [@status, @headers, @response]
  end

end
```

В качестве примера метрик приложения в сервис Post:
- Гистограмму post_read_db_seconds, которая позволяет отследить информацию о времени требуемом для поиска поста в БД

```src/post-py/post-app.py
from flask import Flask, request, Response

import prometheus_client
import time

CONTENT_TYPE_LATEST = str('text/plain; version=0.0.4; charset=utf-8')
REQUEST_DB_LATENCY = prometheus_client.Histogram('post_read_db_seconds', 'Request DB time')
...
@app.route('/metrics')
def metrics():
    return Response(prometheus_client.generate_latest(), mimetype=CONTENT_TYPE_LATEST)
...

@app.route("/post/<id>")
def get_post(id):
    start_time = time.time()
    post = mongo_db.find_one({'_id': ObjectId(id)})
    stop_time = time.time()  # + 0.3
    resp_time = stop_time - start_time
    REQUEST_DB_LATENCY.observe(resp_time)
...
```

```src/post-py/requirements.txt
prometheus_client==0.0.21
flask==0.12.2
pymongo==3.5.1
```

Созданные метрики придадут видимости работы нашего
приложения и понимания, в каком состоянии оно сейчас находится.
Например, время обработки HTTP запроса не должно быть
большим, поскольку это означает, что пользователю приходится
долго ждать между запросами, и это ухудшает его общее
впечатление от работы с приложением. Поэтому большое время
обработки запроса будет для нас сигналом проблемы.
Отслеживая приходящие HTTP-запросы, мы можем, например,
посмотреть, какое количество ответов возвращается с кодом
ошибки. Большое количество таких ответов также будет служить
для нас сигналом проблемы в работе приложения

Добавим информацию о post-сервисе в конфигурацию
Prometheus, чтобы он начал собирать метрики и с него:

```
scrape_configs:
...
  - job_name: 'post'
    static_configs:
      - targets:
        - 'post:5000'
```

Пересоберем образ Prometheus с обновленной конфигурацией:

```
$ export USER_NAME=username # где, usename - ваш логин от DockerHub
$ docker build -t $USER_NAME/prometheus .
```

добавим правило для сервиса post

```
$ gcloud compute firewall-rules create post-default --allow tcp:5000
```

Пересоздадим нашу Docker инфраструктуру мониторинга:

```
$ docker-compose -f docker-compose-monitoring.yml down
$ docker-compose -f docker-compose-monitoring.yml up -d
```

И добавим несколько постов в приложении и несколько комментов, чтобы собрать значения метрик приложения:

Построим графики собираемых метрик приложения. Выберем создать новый дашборд Снова откроем вебинтерфейс Grafana и выберем создание шаблона (Dashboard)
1. Выбираем "Построить график" (New Panel ➡ Graph)
2. Жмем один раз на имя графика (Panel Title), затем выбираем Edit:

Построим для начала простой график изменения счетчика HTTP-запросов по времени. Выберем источник данных и в поле запроса введем название метрики ui_request_count. Далее достаточно нажать мышкой на любое место UI, чтобы убрать курсор из поля запроса, и Grafana выполнит запрос и построит график

В правом верхнем углу мы можем уменьшить временной интервал, на котором строим график, и настроить автообновление данных:

Сейчас мы получили график различных HTTP запросов, поступающих UI сервису. Изменим заголовок графика и описание: Сохраним созданный дашборд:

Построим график запросов, которые возвращают код ошибки на этом же дашборде. Добавим еще один график на наш дашборд. Переходим в режим правки графика. В поле запросов запишем выражение для поиска всех http-запросов, у которых код возврата начинается либо с 4 либо с 5 (используем регулярное выражения для поиска по лейблу). Будем использовать функцию rate(), чтобы посмотреть не просто значение счетчика за весь период наблюдения, но и скорость увеличения данной величины за промежуток времени (возьмем, к примеру 1-минутный интервал, чтобы график был хорошо видим)

В Prometheus есть тип метрик histogram. Данный тип метрик в качестве своего значение отдает ряд распределения измеряемой величины в заданном интервале значений. Мы используем данный тип метрики для измерения времени обработки HTTP запроса нашим приложением.

Рассмотрим пример гистограммы в Prometheus. Посмотрим информацию по времени обработки запроса приходящих на главную страницу приложения. ui_request_latency_seconds_bucket{path="/"}

Эти значения означают, что запросов с временем обработки <= 0.025s было 3 штуки, а запросов 0.01 <= 0.01s было 7 штук (в этот столбец входят 3 запроса из предыдущего столбца и 4 запроса из промежутка [0.025s; 0.01s], такую гистограмму еще называют кумулятивной). Запросов, которые бы заняли > 0.01s на обработку не было, поэтому величина всех последующих столбцов равна 7.

Процентиль:
- Числовое значение в наборе значений
- Все числа в наборе меньше процентиля, попадают в границы заданного процента значений от всего числа значений в наборе

Часто для анализа данных мониторинга применяются значения
90, 95 или 99-й процентиля.
Мы вычислим 95-й процентиль для выборки времени обработки
запросов, чтобы посмотреть какое значение является
максимальной границей для большинства (95%) запросов. Для
этого воспользуемся встроенной функцией histogram_quantile():

Добавьте третий по счету график на ваш дашборд. В поле
запроса введите следующее выражение для вычисления 95
процентиля времени ответа на запрос (gist):

Сохраним изменения дашборда и эспортируем его в JSON файл,
который загрузим на нашу локальную машину. Положите загруженный файл в созданную ранее директорию
monitoring/grafana/dashboards под названием
UI_Service_Monitoring.json

### Сбор метрик бизнеслогики

В качестве примера метрик бизнес логики мы в наше
приложение мы добавили счетчики количества постов и
комментариев
post_count
comment_count
Мы построим график скорости роста значения счетчика за
последний час, используя функцию rate(). Это позволит нам
получать информацию об активности пользователей приложения.

1. Создайте новый дашборд, назовите его Business_Logic_Monitoring
и постройте график функции rate(post_count[1h])
2. Постройте еще один график для счетчика comment,
экспортируйте дашборд и сохраните в директории
monitoring/grafana/dashboards под названием
Business_Logic_Monitoring.json.

Мы определим несколько правил, в которых зададим условия
состояний наблюдаемых систем, при которых мы должны получать
оповещения, т.к. заданные условия могут привести к недоступности
или неправильной работе нашего приложения.
P.S. Стоит заметить, что в самой Grafana тоже есть alerting. Но по
функционалу он уступает Alertmanager в Prometheus.

### Alertmanager

Alertmanager - дополнительный компонент для системы
мониторинга Prometheus, который отвечает за первичную
обработку алертов и дальнейшую отправку оповещений по
заданному назначению.
Создайте новую директорию monitoring/alertmanager. В этой
директории создайте Dockerfile со следующим содержимым:

```
FROM prom/alertmanager:v0.14.0
ADD config.yml /etc/alertmanager/
```

Настройки Alertmanager-а как и Prometheus задаются через
YAML файл или опции командой строки. В директории
monitoring/alertmanager создайте файл config.yml, в котором
определите отправку нотификаций в ВАШ тестовый слак канал.

Для отправки нотификаций в слак канал потребуется создать
СВОЙ Incoming Webhook monitoring/alertmanager/config.yml

```
global:
  slack_api_url: 'https://hooks.slack.com/services/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'

route:
  receiver: 'slack-notifications'

receivers:
- name: 'slack-notifications'
  slack_configs:
  - channel: '#pavel_andreev'
```

1. Соберем образ alertmanager:

```
monitoring/alertmanager $ docker build -t $USER_NAME/alertmanager .
```

2. Добавим новый сервис в компоуз файл мониторинга и добавим его в одну сеть с сервисом Prometheus:

```
  alertmanager:
    image: ${USER_NAME}/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
    ports:
      - 9093:9093
    networks:
      - reddit
      - ui
```

Создадим файл alerts.yml в директории prometheus, в котором
определим условия при которых должен срабатывать алерт и
посылаться Alertmanager-у. Мы создадим простой алерт, который
будет срабатывать в ситуации, когда одна из наблюдаемых систем
(endpoint) недоступна для сбора метрик (в этом случае метрика up с
лейблом instance равным имени данного эндпоинта будет равна
нулю). Выполните запрос по имени метрики up в веб интерфейсе
Prometheus, чтобы убедиться, что сейчас все эндпоинты доступны
для сбора метрик.

Добавим операцию копирования данного файла в Dockerfile:

```monitoring/prometheus/Dockerfile
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
ADD alerts.yml /etc/prometheus/
```

Добавим информацию о правилах, в конфиг Prometheus

```
global:
  scrape_interval: '5s'
...
  rule_files:
    - "alerts.yml"

  alerting:
    alertmanagers:
      - scheme: http
        static_configs:
        - targets:
          - "alertmanager:9093"
```

Пересоберем образ Prometheus:

```
$ docker build -t $USER_NAME/prometheus .
```

Пересоздадим нашу Docker инфраструктуру мониторинга:

```
$ docker-compose -f docker-compose-monitoring.yml down
$ docker-compose -f docker-compose-monitoring.yml up -d
```

Остановим один из сервисов и подождем одну минуту

```
$ docker-compose stop post
```

В канал должно придти сообщение:

[FIRING:q] InstanceDown (post:5000 post)

У Alertmanager также есть свой веб интерфейс, доступный на
порту 9093, который мы прописали в компоуз файле.
P.S. Проверить работу вебхуков слака можно обычным curl.

Запушьте собранные вами образы на DockerHub и удалите виртуалку:

```
$ docker login
Login Succeeded
$ docker push $USER_NAME/ui
$ docker push $USER_NAME/comment
$ docker push $USER_NAME/post
$ docker push $USER_NAME/prometheus
$ docker push $USER_NAME/alertmanager
$ docker-machine rm docker-host
```