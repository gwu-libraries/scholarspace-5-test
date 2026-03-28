# ScholarSpace

## Contributing

If you're working on a PR for this project, create a feature branch off of `main`.

## Production Environment

(terraform instructions coming)

TL;DR  - `bin/prod`
- `db-init` runs database create/migrate automatically before `rails` and `worker` start.
- To run one-off production commands, use docker compose directly with prod files.
- Requires setting AWS_ACCESS_KEY, AWS_SECRET_KEY, AWS_REGION, S3_BUCKET_NAME, and S3_PREFIX in .env.

## Development Environment

- `bin/dev` 
  - creates and starts docker containers in development mode.
  - `db-init` runs database create/migrate/seed automatically before `rails` and `worker` start.
  - The app source is bind-mounted into containers, so code edits apply immediately without rebuilding images.
  - Requires `.env` setting 

## Tests

TL;DR - `bin/test`if you want to end-to-end test or for CI runs, but this is *slow*, otherwise run devopment environment, attach to rails container, run `bundle exec rspec`

- Similarly to development environment, this uses a bind mount to sync local and container code.
- The `rspec` service in docker-compose-test.yml runs `RAILS_ENV=test bundle exec rails db:prepare` before `bundle exec rspec`.

