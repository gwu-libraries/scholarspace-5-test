# ScholarSpace

## Contributing

If you're working on a PR for this project, create a feature branch off of `main`.

## Production Environment

- Update environment variables:
  - RAILS_ENV=production
  - METADATA_DATABASE_NAME=scholarspace_metadata_production (todo: fix this)
  - PUMA_ENV=production (todo: fix this)
- Update `docker-compose.yml` to include `docker-compose-prod.yml` and not `docker-compose-dev.yml`

## Development Environment

- Update environment variables:
- RAILS_ENV=development
- METADATA_DATABASE_NAME=scholarspace_metadata_development (todo: fix this)
- PUMA_ENV=development (todo: fix this)
- Update `docker-compose.yml` to include `docker-compose-dev.yml` and not `docker-compose-prod.yml`

## Tests

- To run tests, launch the application in development mode. 
- Connect to the rails container (`docker exec -it rails /bin/sh`)
- Run `bundle exec rspec`

At the moment, there are 8 failing tests. Issue appears to be more with the test setup, so consider 8 failing tests passing for now, but needs to be fixed at some point. 
