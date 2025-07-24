#!/bin/sh

./bin/rails db:create db:migrate RAILS_ENV=development

exec "${@}"