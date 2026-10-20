# ScholarSpace

## Develop

Create a feature branch from `main`. For local development, copy
`example.dev.env` to `dev.env`, then start the application with `bin/dev`.
Run the test suite with `bundle exec rspec` from the Rails container.

Production images are built from the targets in `Dockerfile` and deployed with
the ECS task definitions in `terraform/`. See
[`script/rebuild-and-push-all-images.sh`](script/rebuild-and-push-all-images.sh)
for image publishing.

## Customizations

The application customizes the Hyrax work and file experience across the data
model, indexing, background processing, and React interface:

| Area | Overview |
| --- | --- |
| Work types and file sets | ETDs, journal issues, academic and archival documents, with shared file-set behavior. See [model notes](app/models/readme.md). |
| Work pages | Access-aware file lists, transcripts, viewer data, and page props. See [presenter notes](app/presenters/readme.md) and [props-builder notes](app/props_builders/readme.md). |
| Frontend | React work pages with image, PDF, and audiovisual viewers, deep search, and catalog date-range tools. See [JavaScript notes](app/javascript/readme.md). |
| Derivatives and IIIF | File processing, derivative caching, viewer manifests, and file selection. See [service notes](app/services/readme.md). |
| Background jobs | Asynchronous derivative orchestration, persistence, queueing, and duplicate-work protection. See [job notes](app/jobs/readme.md). |
| Search | Solr indexing of work metadata and searchable text from files. See [indexer notes](app/indexers/readme.md). |

Operational behavior is configured alongside the application:

- Sidekiq uses separate worker pools and queue definitions in
  [`config/sidekiq/`](config/sidekiq) and [`config/sidekiq.yml`](config/sidekiq.yml).
- Derivative quality, scheduling, and service settings are in
  [`config/derivative_settings.yml`](config/derivative_settings.yml).
- Local development uses Docker Compose; production sizing and deployment are
  managed in [`terraform/`](terraform).
