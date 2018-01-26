# Docker build environment for ruby on rails project

*Goal:*  To establish a dockerised development environment for a standard rails application.

*Why:* To create a standardised base level development environment with no need to install local gems, version management etc.

The process involves creating a basic docker machine
    Installing onto it the necessary tools to create a development environment
    Installing the bundler program, using it to install binstubs, then using the rails program to generate a clean rails application.
    The folder into which the app is created is then exposed as a volume to the host system. You can then use your dev tools on the host to start writing code.

## Components:

*To start with:*
    Dockerfile-dev
    Almost empty Gemfile and empty Gemfile.lock
    docker-compose-dev.yml

*Containers added in later:*
    Gem repository
    Nginx
    memcached
    redis
    sidekiq

*Core Elements:*
    Based on ruby-alpine
    Install build-base and necessary libs
    Create a folder for source code and some start-up scripts
    Use an external data volume to host gems - so you don't have to do a full rebuild every time a gem is added

Firstly ensure VirtualBox is running with a running VM (using default in my case).

## Get Docker running

Create a host machine - note: can be named anything, I'm using the name of the app to identify it.

Note: I've created two aliases for docker (save on the typing) dm for docker-machine and dc for docker-compose.

```sh
$ cd projects/dockerdemo
$ dm create dockerdemo
$ eval "$(docker-machine env dockerdemo)"
```

Create project folder and create a docker-compose and Dockerfile

```sh
touch Dockerfile
touch docker-compose-dev.yml
```

Copy basic instructions into Dockerfile to:
    create initial build environment
    create the app source code folder and startup script
    copy over the application Gemfile from local environment
    set essential build paths and environment variables
    install bindler
    install gems
    install binaries (—binstubs)
    expose the application port (3000)

```
FROM ruby:2.4.3-alpine
MAINTAINER Peter Mac <peter@petermac.com>

RUN apk add --update --no-cache \
      build-base \
      nodejs \
      tzdata \
      libxml2-dev \
      libxslt-dev \
      postgresql-dev \
      bash

ENV APP_HOME="/usr/src/app" \
  DOCKER_DIR="/usr/src/docker" \
  PATH="/ruby_gems/bundle/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN mkdir -p ${APP_HOME} && \
  mkdir -p ${DOCKER_DIR}
WORKDIR $APP_HOME

COPY ./Gemfile* $APP_HOME/
COPY ./docker/* $DOCKER_DIR/
COPY . /$APP_HOME

ENV BUNDLE_GEMFILE=${APP_HOME}/Gemfile \
  BUNDLE_PATH="/ruby_gems" \
  BUNDLE_JOBS=20 \
  BUNDLE_RETRY=5 \
  GEM_HOME="/ruby_gems"

RUN gem install bundler

EXPOSE 3000
```
---

The docker-compose file is used to coordinate the build environment

```
version: '2'
volumes:
  # We'll define a volume that will store the data from the postgres databases:
  postgres-data:
    driver: local

  public:
    driver: local

  app:
    driver: local

services:
  #The postgres database service
  postgres:
    image: postgres:9.4
    ports:
      - '5432:5432'
    env_file:
      - .env-dev
    volumes:
      # mount the 'postgres-data' volume into the location Postgres stores it's data:
      - postgres-data:/var/lib/postgresql/data

  # The web service
  app: &app_base
    build:
      context: ./
      dockerfile: Dockerfile-dev
    command: /usr/src/docker/startup.sh
    env_file:
        - .env-dev
    volumes:

      - app:/usr/src/app

    volumes_from:
        - gems

    ports:
      - '3000:3000'

    # Keep the stdin open, so we can attach to our app container's process and do things such as
    # byebug, etc:
    stdin_open: true

    # Enable sending signals (CTRL+C, CTRL+P + CTRL+Q) into the container:
    tty: true

    links:

      # Include a link to the 'db' (postgres) container, making it visible from the container
      # using the 'postgres.local' hostname (which is not necessary, but I'm doing it here to
      # illustrate that you can play with this):
      - postgres:postgres.local
    depends_on:
      - gems

  gems:
    image: busybox
    command: /bin/sh
    volumes:
      - /ruby_gems
```
---

Next build the docker containers and get them up and running
```sh
dc -f docker-compose-dev.yml build
dc -f docker-compose-dev.yml up --no-start
dc -f docker-compose-dev.yml up
```

Check there's no errors being reported back.

Then create the new rails application in the app container

```sh
dc -f docker-compose-dev.yml run --rm app bundle exec rails new . -d postgresql
```


now to get the created folders exposed to the outside world
dc -f docker-compose-dev up —no-start
