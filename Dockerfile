ARG ALPINE_VERSION=3.21
ARG RUBY_VERSION=3.3.6

FROM ruby:$RUBY_VERSION-alpine$ALPINE_VERSION AS scholarspace-base

ARG DATABASE_APK_PACKAGE="postgresql-dev"
ARG EXTRA_APK_PACKAGES="git"
ARG RUBYGEMS_VERSION=""

RUN addgroup -S --gid 101 app && \
    adduser -S -G app -u 1001 -s /bin/sh -h /app app

RUN apk --no-cache upgrade && \
  apk --no-cache add acl \
  build-base \
  curl \
  gcompat \
  imagemagick \
  imagemagick-heic \
  imagemagick-jpeg \
  imagemagick-jxl \
  imagemagick-pdf \
  imagemagick-svg \
  imagemagick-tiff \
  imagemagick-webp \
  jemalloc \
  ruby-grpc \
  tzdata \
  nodejs \
  yarn \
  zip \
  $DATABASE_APK_PACKAGE \
  $EXTRA_APK_PACKAGES

RUN setfacl -d -m o::rwx /usr/local/bundle && \
  gem update --silent --system $RUBYGEMS_VERSION

USER app

RUN mkdir -p /app/scholarspace
WORKDIR /app/scholarspace

ENV PATH="/app/scholarspace:$PATH" \
    RAILS_ENV="production" \
    RAILS_ROOT="/app/scholarspace" \
    RAILS_SERVE_STATIC_FILES="1" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so.2"

COPY Gemfile ./

RUN bundle config set without development test 

RUN bundle install

COPY . ./

COPY --chmod=755 ./bin/docker-entrypoint .

USER root

RUN chmod 755 -R ./log/

FROM scholarspace-base AS scholarspace

RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production ./bin/rails assets:precompile

ENTRYPOINT ["docker-entrypoint"]
CMD ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]

FROM scholarspace-base AS scholarspace-worker

USER root
RUN apk --no-cache add bash \
  ffmpeg \
  mediainfo \
  openjdk17-jre \
  perl
USER app

RUN mkdir -p /app/fits && \
    cd /app/fits && \
    wget https://github.com/harvard-lts/fits/releases/download/1.6.0/fits-1.6.0.zip -O fits.zip && \
    unzip fits.zip && \
    rm fits.zip tools/mediainfo/linux/libmediainfo.so.0 tools/mediainfo/linux/libzen.so.0 && \
    chmod a+x /app/fits/fits.sh && \
    sed -i 's/\(<tool.*TikaTool.*>\)/<!--\1-->/' /app/fits/xml/fits.xml
ENV PATH="${PATH}:/app/fits"

CMD ["bundle", "exec", "sidekiq"]