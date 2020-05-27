FROM ruby:2.4

RUN apt-get update && apt-get install -y build-essential

COPY . /app

WORKDIR /app
RUN bundle install
ENV DATABASE_URL mongodb://mongo
EXPOSE 9292

CMD ["puma"]
