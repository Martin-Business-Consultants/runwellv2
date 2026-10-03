# syntax=docker/dockerfile:1
# Runwell v2's production image, for Kamal (config/deploy.yml). Importmap and Propshaft, so no
# Node: assets precompile with Ruby alone. Plugins aren't in the image: they live in the data
# volume (RUNWELL_DATA_DIR/plugins), and the entrypoint compiles their assets on boot.

# The Debian release is pinned with the base (RUNWELL_BASE): the Ruby each release carries is built
# on it, so an install updating in place keeps a system it runs on.
ARG RUBY_VERSION=4.0.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim-trixie AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# RUNWELL_BASE counts changes to this stage (Ruby aside, which travels with each release): bump it
# when a release needs other system packages or a newer Debian, so an install updating in place
# (Upgrade::InPlace) redeploys instead.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RUNWELL_RUNTIME="docker" \
    RUNWELL_BASE="1"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev libssl-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN gem install bundler -v '~> 4.0'

COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# The release bundle an install updates itself with (Upgrade::InPlace): the app as built, with
# its gems in bundle/ and the Ruby they were built for in ruby/ (config/bundled_ruby.rb switches
# to it), so a new Ruby updates in place too. The release workflow exports it for each
# architecture and checks it boots on another Ruby (bin/check-bundle).
FROM scratch AS bundle
COPY --from=build /rails /
COPY --from=build /usr/local/bundle /bundle
COPY --from=build /usr/local/bin /ruby/bin
COPY --from=build /usr/local/lib /ruby/lib

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp && chown -R rails:rails db log public storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster listens on 80 and runs Puma on 3000 behind it (gzip, asset caching, X-Sendfile).
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
