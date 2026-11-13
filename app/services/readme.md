# Services

Services are grouped by responsibility using namespaces that match their
directories. Specs mirror these groups under `spec/services/`.

| Directory | Namespace | Responsibility |
| --- | --- | --- |
| [`characterization/`](characterization) | `Characterization` | Large-file metadata characterization and FITS delegation |
| [`configuration/`](configuration) | `Configuration` | Derivative processing settings and Redis connection settings |
| [`derivatives/cache/`](derivatives/cache) | `Derivatives::Cache` | Filesystem/S3 cache stores, cache keys, and PDF optimization |
| [`derivatives/`](derivatives) | `Derivatives` | Derivative generation, persistence, constants, and file processing |
| [`hyrax/custom_queries/`](hyrax/custom_queries) | `Hyrax::CustomQueries` | Repository query extensions |
| [`iiif_builders/`](iiif_builders) | `IiifBuilders` | Viewer-specific IIIF manifest implementations |
| [`ingest/`](ingest) | `Ingest` | Stale-upload recovery and ingest lifecycle instrumentation |
| [`resolvers/`](resolvers) | `Resolvers` | Derivative linkage, thumbnail selection, and work-viewer file selection |

[`Derivatives::Cache::Service`](derivatives/cache/service.rb) coordinates the
cache implementations from within the cache directory. The manifest entry point,
[`IiifBuilders::ManifestBuilder`](iiif_builders/manifest_builder.rb), lives
alongside its viewer-specific builders.

## Derivatives and configuration

Custom derivative services contain the processing and persistence logic used by
the jobs in [`app/jobs`](../jobs/readme.md).

Generation services are organized by resource level and derivative type under
[`derivatives/`](derivatives): file-set services create thumbnails, presentation
versions, OCR text, and transcripts; work-level services select representative
files and build work-wide derivatives such as reading-mode PDFs.

Generation services prepare derivative files and place them in
`Derivatives::Cache::Service`; persistence attaches those files to the work as service
file sets and reindexes affected resources.

Shared mixins are grouped by responsibility rather than under a generic
`concerns/` directory. They remain mixins; this organization does not change
their processing or persistence behavior:

| Directory | Shared behavior |
| --- | --- |
| [`derivatives/cache/`](derivatives/cache) | Cache writes, alongside cache stores and optimization |
| [`derivatives/locking/`](derivatives/locking) | Work advisory locking |
| [`derivatives/persistence/`](derivatives/persistence) | File-set attachment and derivative metadata |
| [`derivatives/source_files/`](derivatives/source_files) | Source MIME-type detection |
| [`derivatives/text_extraction/`](derivatives/text_extraction) | HOCR generation and merging, alongside the document merger |
| [`derivatives/thumbnail_creation/`](derivatives/thumbnail_creation) | Thumbnail generation |
| [`derivatives/transcript_extraction/`](derivatives/transcript_extraction) | VTT generation and WAV conversion |

[`Configuration::DerivativeSettings`](configuration/derivative_settings.rb)
reads tunable service settings from `config/derivative_settings.yml`.
[`Configuration::RedisSettings`](configuration/redis_settings.rb) provides Redis
connection settings and the distributed-lock connection pool.
Shared identifiers and file-type constants live under
[`Derivatives::Constants`](derivatives/constants), with one module per file so
Rails can autoload them normally. No manual constants-loading initializer is
needed.

## IIIF manifests

[`IiifBuilders::ManifestBuilder`](iiif_builders/manifest_builder.rb) is the controller-facing entry
point for IIIF Presentation 3 manifests. Its class and instance methods,
`manifest_for` and `manifest_json_for`, accept `presenter:` and `viewer:`.
The `ramp` viewer selects RAMP; missing or unrecognized viewers default to Clover.

Viewer implementations live under `iiif_builders/` in the `IiifBuilders` namespace:

- [`Base`](iiif_builders/base.rb) assembles the shared manifest envelope
  and thumbnails and provides member selection, metadata, and URL helpers.
- [`Clover`](iiif_builders/clover.rb) builds image canvases, image service
  bodies, and search-service metadata.
- [`Ramp`](iiif_builders/ramp.rb) builds audiovisual canvases, media
  bodies, durations, and transcript annotations.

## Work viewer file selection

[`Resolvers::WorkViewerResolver`](resolvers/work_viewer_resolver.rb) selects the
files exposed by the work viewer: presentation derivatives for downloads, the
reading-mode or presentation PDF, and linked HOCR. It also determines whether
source images have viewable presentation derivatives. It reuses
[`Resolvers::DerivativeLinkResolver`](resolvers/derivative_link_resolver.rb) for
source linkage and HOCR resolution and caches member lookups within each resolver
instance.

`WorkViewerHelper` keeps URL generation in the view layer and delegates file
selection to a resolver cached per work in the view context. Source files are
not substituted for missing presentation derivatives. Reading-mode PDFs take
priority over individual presentation PDFs; PDF presentation derivatives require
the presentation-version metadata tag, while other presentation files also
support the existing filename fallback.

[`Resolvers::ThumbnailResolver`](resolvers/thumbnail_resolver.rb) resolves
persisted service-file thumbnails and representative work thumbnails for
presenters, models, and work-show props.
