#!/bin/sh

# If running the rails server then create or migrate existing database
# if [ "${1}" == "./bin/rails" ] && [ "${2}" == "server" ]; then
./bin/rails db:create db:migrate RAILS_ENV=production
# fi

exec "${@}"