FROM ruby:3.1

WORKDIR /opt/app
ADD Gemfile .
ADD Gemfile.lock .

RUN apt-get install libpq-dev \
    && bundle config set --local set path vendor/bundle \
    && bundle install

EXPOSE 4567