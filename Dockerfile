ARG ALPINE_VERSION=3.21
ARG RUBY_VERSION=3.3.6
ARG BUILD_ENV
ARG EXTRA_APK_PACKAGES=""
ARG RUBYGEMS_VERSION=""

FROM ruby:$RUBY_VERSION-alpine$ALPINE_VERSION AS scholarspace-base

ARG BUILD_ENV
ARG EXTRA_APK_PACKAGES=""
ARG RUBYGEMS_VERSION=""

RUN addgroup -S --gid 101 app && \
    adduser -S -G app -u 1001 -s /bin/sh -h /app app

RUN apk --no-cache upgrade && \
  apk --no-cache add acl \
  build-base \
  curl \
  gcompat \
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
  postgresql-dev \
  git \
  jemalloc \
  ruby-grpc \
  tzdata \
  nodejs \
  yarn \
  libxml2 \
  libxml2-dev \
  poppler-utils \
  cmake \
  $EXTRA_APK_PACKAGES

RUN setfacl -d -m o::rwx /usr/local/bundle && \
  gem update --silent --system $RUBYGEMS_VERSION

USER app

RUN mkdir -p /app/scholarspace
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

COPY --chown=app:app . ./

RUN if [ "$BUILD_ENV" = "prod" ]; then \
      yarn install && yarn build:prod; \
    elif [ "$BUILD_ENV" = "dev" || "$BUILD_ENV" = "test" ]; then \
      yarn install && yarn build:dev || true; \
    fi

RUN if [ "$BUILD_ENV" = "prod" ]; then \
      RAILS_ENV=production SECRET_KEY_BASE=dummy bundle exec rails assets:precompile; \
    fi
