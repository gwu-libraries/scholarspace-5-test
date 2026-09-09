# ScholarSpace

## Contributing

If you're working on a PR for this project, create a feature branch off of `main`.

## Production Environment

Production does not run with Docker Compose. Runtime images are built from the
explicit production targets in `Dockerfile`, pushed to ECR, and deployed by the
Terraform ECS task definitions in `terraform/`.

- Build and push production images with `script/rebuild-and-push-all-images.sh`.
- Pass image URIs to Terraform through `terraform/terraform.tfvars` or run the
  image push script with `--update-tfvars`.

## Development Environment

- Local development uses `docker-compose.yml` plus `docker-compose-dev.yml`.
- Copy `example.dev.env` to `dev.env` and adjust local values as needed.
- Start the stack with `docker compose -f docker-compose.yml -f docker-compose-dev.yml up --build`.
- The `rails`, `worker`, and specialized `worker_*` services all build the
  `scholarspace-default` Dockerfile target with `BUILD_ENV=dev`. The worker
  variants use the same image and are separated by their `SIDEKIQ_ONLY_*`
  environment flags.

## Tests

- To run tests, launch the application in development mode. 
- Connect to the rails container (`docker exec -it rails /bin/sh`)
- Run `bundle exec rspec`

At the moment, there are 8 failing tests. Issue appears to be more with the test setup, so consider 8 failing tests passing for now, but needs to be fixed at some point. 
