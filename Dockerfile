# syntax=docker/dockerfile:1
# Runwell v2's production image, for Kamal (config/deploy.yml). Importmap and Propshaft, so no
# Node: assets precompile with Ruby alone. The plugin engines (bundled in engines/, installed in
# plugins/) are path gems, so they are copied in before bundling.

ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev libssl-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install bundler -v '~> 4.0'

COPY .ruby-version Gemfile Gemfile.lock ./
COPY engines/ engines/
COPY plugins/ plugins/
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster listens on 80 and runs Puma on 3000 behind it (gzip, asset caching, X-Sendfile).
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
