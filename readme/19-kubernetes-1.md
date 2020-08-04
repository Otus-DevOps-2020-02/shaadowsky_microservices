## Kubernetes intro

- разобрать на практике все компоненты kubernetes, оахвернуть их вручную используя hard way
- ознакомиться с описанием основных примитивов нашего приложения и его дальнейшим запуском в kubernetes

### создание примитивов

опишем приложение в контексте kubernetes с помощью манифестов в yaml-формате. Основным примитивом будет _Deployment_, в задачи которого входит:

- создание _Replication Controller_, следящего за тем, чтобы число запущенных подов (Pods) соотвтествовало описаннному;
- ведение истории версий запущенных подов (для различных стратегий деплоя и возможности отката);
- описание процесса деплоя (стратегии и их параметры)

По ходу выполнения манифесты будут обновляться и появляться новые. Текущие файлы нужы для создания структуры и проверки работоспособности kubernetes-кластера.

создаем директорию _kubernetes/reddit_ в корне репозитория, внутри неё создаем файлы post-deployment.yml и по его образцу ui-deployment.yml, comment-deployment.yml и mongo-deployment.yml

```post-deployment.yml
---
apiVersion: apps/v1beta2
kind: Deployment
metadata:
  name: post-deployment
spec:
  replicas: 1 # Указатель на то, какие поды нужно поддерживать в нужном количестве
  selector:
    matchLabels:
      app: post
  template:
    metadata:
      name: post
      labels:
        app: post
    spec:
      containers:
      - image: <Вставьте ваш образ>/post
        name: post
```

В результате будут нерабочие экземпляры.

Пробуем установить кубер по [hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

- Создать отдельную директорию the_hard_way в директории kubernetes;
- Пройти Kubernetes The Hard Way;
- Проверить, что kubectl apply -f <filename> проходит по созданным до этого deployment-ам (ui, post, mongo, comment) и поды запускаются;
- Удалить кластер после прохождения THW;
- Все созданные в ходе прохождения THW файлы (кроме бинарных) поместить в папку kubernetes/the_hard_way репозитория (сертификаты и ключи тоже можно коммитить, но только после удаления кластера).

