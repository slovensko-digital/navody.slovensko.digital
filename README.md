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
 - `bundle install`
 - `yarn`
 - premenuj `.env.sample` na `.env`
 - `bin/setup`
 - `bin/rails s`

#### Test Enviroment

Na spustenie system testov:

 - `bin/rails db:create`
 - `bin/rails db:setup`
 - `bin/rake`

### Neprogramátorské úlohy

Wishlist ďalších návodov na spracovanie a editovanie, eventy a ďalší progress nájdete na https://trello.com/b/4tkVI6vr/n%C3%A1vodydigital

