ARG ALPINE_VERSION=3.21
ARG RUBY_VERSION=3.3.6
ARG BUILD_ENV
ARG EXTRA_APK_PACKAGES=""
ARG RUBYGEMS_VERSION=""

FROM ruby:$RUBY_VERSION-alpine$ALPINE_VERSION AS scholarspace-builder-base

ARG BUILD_ENV
ARG EXTRA_APK_PACKAGES=""
ARG RUBYGEMS_VERSION=""

RUN addgroup -S --gid 101 app && \
    adduser -S -G app -u 1001 -s /bin/sh -h /app app

RUN apk --no-cache upgrade && \
  apk --no-cache add acl \
  build-base \
  cmake \
  curl \
  gcompat \
  libreoffice \
  vips \
  libxml2 \
  libxml2-dev \
  postgresql-dev \
  git \
  jemalloc \
  ruby-grpc \
  tzdata \
  ffmpeg \
  $EXTRA_APK_PACKAGES

RUN setfacl -d -m o::rwx /usr/local/bundle && \
  if [ -n "$RUBYGEMS_VERSION" ]; then gem update --silent --system "$RUBYGEMS_VERSION"; fi

USER app

RUN mkdir -p /app/scholarspace \
  /app/scholarspace/tmp/cache/solr-ocr-index-cache
WORKDIR /app/scholarspace

# lets just set the adapters here so its explicitly the same in each environment
ENV PATH="/app/scholarspace:$PATH" \
    RAILS_ROOT="/app/scholarspace" \
    RAILS_SERVE_STATIC_FILES="1" \
    VALKYRIE_METADATA_ADAPTER="fedora_metadata" \
    VALKYRIE_STORAGE_ADAPTER="fedora_storage" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"

COPY --chown=app:app Gemfile Gemfile.lock ./

# if prod, leave out dev/test gems
RUN if [ "$BUILD_ENV" = "prod" ]; then \
      bundle config set without development test; \
    fi

RUN bundle config set deployment true
RUN bundle install

FROM scholarspace-builder-base AS scholarspace-web-builder

ARG BUILD_ENV

USER root

RUN apk --no-cache add nodejs yarn

USER app

COPY --chown=app:app package.json yarn.lock ./

RUN if [ "$BUILD_ENV" = "prod" ] || [ "$BUILD_ENV" = "dev" ] || [ "$BUILD_ENV" = "test" ]; then \
      yarn install --frozen-lockfile --network-timeout 600000; \
    fi

COPY --chown=app:app . ./

RUN if [ "$BUILD_ENV" = "prod" ]; then \
      yarn build:prod; \
    elif [ "$BUILD_ENV" = "dev" ] || [ "$BUILD_ENV" = "test" ]; then \
      yarn build:dev || true; \
    fi

RUN if [ "$BUILD_ENV" = "prod" ]; then \
      RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile; \
    fi

RUN if [ "$BUILD_ENV" = "prod" ]; then \
  ls /app/scholarspace/public/assets/application-*.css* >/dev/null 2>&1; \
    fi

FROM scholarspace-builder-base AS scholarspace-sidekiq-builder

COPY --chown=app:app . ./

RUN mkdir -p /app/scholarspace/tmp/derivatives-work-locks

FROM ruby:$RUBY_VERSION-alpine$ALPINE_VERSION AS scholarspace-web-prod

ARG EXTRA_APK_PACKAGES=""

RUN addgroup -S --gid 101 app && \
    adduser -S -G app -u 1001 -s /bin/sh -h /app app

RUN apk --no-cache upgrade && \
  apk --no-cache add acl \
  curl \
  gcompat \
  libreoffice \
  vips \
  imagemagick \
  imagemagick-heic \
  imagemagick-jpeg \
  imagemagick-jxl \
  imagemagick-pdf \
  imagemagick-svg \
  imagemagick-tiff \
  imagemagick-webp \
  ghostscript \
  ffmpeg \
  tesseract-ocr \
  tesseract-ocr-data-eng \
  poppler-utils \
  zip \
  jemalloc \
  ruby-grpc \
  tzdata \
  libxml2 \
  $EXTRA_APK_PACKAGES

USER app

RUN mkdir -p /app/scholarspace \
  /app/scholarspace/tmp/cache/solr-ocr-index-cache
WORKDIR /app/scholarspace

ENV PATH="/app/scholarspace:$PATH" \
    RAILS_ROOT="/app/scholarspace" \
    RAILS_SERVE_STATIC_FILES="1" \
    VALKYRIE_METADATA_ADAPTER="fedora_metadata" \
    VALKYRIE_STORAGE_ADAPTER="fedora_storage" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"

COPY --from=scholarspace-web-builder --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=scholarspace-web-builder --chown=app:app /app/scholarspace /app/scholarspace

FROM ruby:$RUBY_VERSION-alpine$ALPINE_VERSION AS scholarspace-sidekiq-default-prod

ARG EXTRA_APK_PACKAGES=""

RUN addgroup -S --gid 101 app && \
    adduser -S -G app -u 1001 -s /bin/sh -h /app app

RUN apk --no-cache upgrade && \
  apk --no-cache add acl \
  curl \
  gcompat \
  libreoffice \
  vips \
  imagemagick \
  imagemagick-heic \
  imagemagick-jpeg \
  imagemagick-jxl \
  imagemagick-pdf \
  imagemagick-svg \
  imagemagick-tiff \
  imagemagick-webp \
  ghostscript \
  ffmpeg \
  tesseract-ocr \
  tesseract-ocr-data-eng \
  zip \
  jemalloc \
  ruby-grpc \
  tzdata \
  libxml2 \
  $EXTRA_APK_PACKAGES

USER app

RUN mkdir -p /app/scholarspace \
  /app/scholarspace/tmp/cache/solr-ocr-index-cache \
  /app/scholarspace/tmp/derivatives-work-locks
WORKDIR /app/scholarspace

ENV PATH="/app/scholarspace:$PATH" \
    RAILS_ROOT="/app/scholarspace" \
    RAILS_SERVE_STATIC_FILES="1" \
    VALKYRIE_METADATA_ADAPTER="fedora_metadata" \
    VALKYRIE_STORAGE_ADAPTER="fedora_storage" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"

COPY --from=scholarspace-sidekiq-builder --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=scholarspace-sidekiq-builder --chown=app:app /app/scholarspace /app/scholarspace
COPY --from=scholarspace-web-builder --chown=app:app /app/scholarspace/public/assets /app/scholarspace/public/assets
COPY --from=scholarspace-web-builder --chown=app:app /app/scholarspace/public/packs /app/scholarspace/public/packs

FROM scholarspace-sidekiq-default-prod AS scholarspace-sidekiq-whisper-prod

USER root

RUN apk --no-cache add ffmpeg

USER app

FROM scholarspace-sidekiq-default-prod AS scholarspace-sidekiq-ocr-text-prod

USER root

RUN apk --no-cache add tesseract-ocr tesseract-ocr-data-eng poppler-utils

USER app

FROM ruby:$RUBY_VERSION-alpine$ALPINE_VERSION AS scholarspace-sidekiq-prod

ARG EXTRA_APK_PACKAGES=""

RUN addgroup -S --gid 101 app && \
    adduser -S -G app -u 1001 -s /bin/sh -h /app app

RUN apk --no-cache upgrade && \
  apk --no-cache add acl \
  curl \
  gcompat \
  libreoffice \
  vips \
  imagemagick \
  imagemagick-heic \
  imagemagick-jpeg \
  imagemagick-jxl \
  imagemagick-pdf \
  imagemagick-svg \
  imagemagick-tiff \
  imagemagick-webp \
  ghostscript \
  tesseract-ocr \
  tesseract-ocr-data-eng \
  ffmpeg \
  zip \
  jemalloc \
  ruby-grpc \
  tzdata \
  libxml2 \
  poppler-utils \
  $EXTRA_APK_PACKAGES

USER app

RUN mkdir -p /app/scholarspace
WORKDIR /app/scholarspace

ENV PATH="/app/scholarspace:$PATH" \
    RAILS_ROOT="/app/scholarspace" \
    RAILS_SERVE_STATIC_FILES="1" \
    VALKYRIE_METADATA_ADAPTER="fedora_metadata" \
    VALKYRIE_STORAGE_ADAPTER="fedora_storage" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"

COPY --from=scholarspace-sidekiq-builder --chown=app:app /usr/local/bundle /usr/local/bundle
COPY --from=scholarspace-sidekiq-builder --chown=app:app /app/scholarspace /app/scholarspace
COPY --from=scholarspace-web-builder --chown=app:app /app/scholarspace/public/assets /app/scholarspace/public/assets
COPY --from=scholarspace-web-builder --chown=app:app /app/scholarspace/public/packs /app/scholarspace/public/packs

# Keep default target aligned with existing compose workflows that build a
# single image for both rails and worker containers.
FROM scholarspace-web-builder AS scholarspace-default
