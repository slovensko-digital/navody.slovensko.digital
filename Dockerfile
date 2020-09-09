FROM ruby:2.6.6-buster

ARG user=sk

RUN useradd -m -s /bin/bash ${user} && \
  # Add node repo
  curl -sSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
  echo "deb https://deb.nodesource.com/node_12.x buster main" | tee /etc/apt/sources.list.d/nodesource.list && \
  # Add postgresql repo
  curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
  # Add yarn repo
  curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  # Install node
  nodejs \
  # Install pg gem deps
  libpq-dev \
  postgresql-client-12 \
  # Install yarn
  yarn && \
  rm -rf /var/lib/apt/lists/* && \
  # Install bundler version to match Gemfile.lock
  gem install bundler:2.1.4 && \
  # Create directories for docker volumes
  mkdir -p /app/vendor/bundle /app/node_modules && \
  chown ${user}: /app/vendor/bundle /app/node_modules

WORKDIR /app
USER ${user}
ENV RAILS_ENV=development
RUN bundle config set deployment true