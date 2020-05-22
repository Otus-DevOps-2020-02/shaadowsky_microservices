FROM alpine:3.7

ENV APP_HOME /app
ENV POST_SERVICE_HOST post
ENV POST_SERVICE_PORT 5000
ENV COMMENT_SERVICE_HOST comment
ENV COMMENT_SERVICE_PORT 9292
ENV network=reddit

RUN apk update && \
    apk upgrade && \
    apk add build-base && \
    apk add ruby ruby-bundler ruby-dev && \
    rm -rf /var/cache/apk/* && \
    mkdir $APP_HOME

WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install
ADD . $APP_HOME

EXPOSE 9292

CMD ["puma"]
