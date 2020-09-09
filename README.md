# Návody.digital

[![Build](https://img.shields.io/circleci/build/github/slovensko-digital/navody.digital)](https://circleci.com/gh/slovensko-digital/navody.digital)
[![Coverage](https://img.shields.io/codeclimate/coverage/slovensko-digital/navody.digital)](https://codeclimate.com/github/slovensko-digital/navody.digital)
[![Maintainability](https://img.shields.io/codeclimate/maintainability/slovensko-digital/navody.digital)](https://codeclimate.com/github/slovensko-digital/navody.digital)

### Deployment

Master ide automaticky na https://staging.navody.digital/

### Setup

#### OSX (homebrew)

- `brew install postgresql`
- `brew services start postgresql`
- `bin/setup`
- `bin/rails s`

#### Docker

- Download & install:
  - [git](https://git-scm.com/downloads)
  - [Docker CE](https://docs.docker.com/install/)
  - [Docker Compose](https://docs.docker.com/compose/install/) 
- Clone the git repo: `git clone git@github.com:slovensko-digital/navody.digital.git`
- Move into the newly cloned directory: `cd navody.digital`
- Build docker image and start the development environment: `docker-compose up --build -d`. Note: this needs to be run only on first setup and then only on `Dockerfile`/`docker-compose.yml` change
- Setup the environment:
  - Attach to the `app` container: `docker-compose exec app bash`
  - (Optional) Install node modules: `yarn`
  - Run the setup command (installs gems, prepares DB, ..): `bin/setup`
  - Start the rails server: `bin/rails s`
- To stop the environment, run: `docker-compose stop`
- To start it again, run: `docker-compose start`

#### Test Enviroment

Na spustenie system testov:

- `bin/rails db:create`
- `bin/rails db:setup`
- `bin/rake`

### Neprogramátorské úlohy

Wishlist ďalších návodov na spracovanie a editovanie, eventy a ďalší progress nájdete na https://trello.com/b/4tkVI6vr/n%C3%A1vodydigital

