#!/usr/bin/env bash
set -e

if [[ -z "${TEST_CONFIGURATION}" ]]; then
  echo "The TEST_CONFIGURATION environment variable is missing." >&2
  echo "This should have been provided by the Tekton Task or the developer" >&2
  exit 1
fi

if [[ -z "${BUNDLE_GEMFILE}" ]]; then
  echo "The BUNDLE_GEMFILE environment variable is missing." >&2
  echo "This should have been provided by the Tekton Task or the developer" >&2
  exit 2
fi

if [[ -z "${RUBY_VERSION}" ]]; then
  echo "The RUBY_VERSION environment variable is missing." >&2
  echo "This is a built-in variable in the official ruby container images" >&2
  exit 3
fi

case "${TEST_CONFIGURATION}" in
libraries)
  export COVERAGE_PATH="cov_$(basename ${BUNDLE_GEMFILE%.gemfile})_ruby_${RUBY_VERSION}"
  export APPRAISAL_INITIALIZED=1 ;;
rails)
  if [[ -z "${DATABASE_URL}" ]]; then
    echo -n "The TEST_CONFIGURATION is set to ${TEST_CONFIGURATION}. " >&2
    echo    "But the DATABASE_URL environment variable is missing." >&2
    exit 4
  else
    echo "DATABASE_URL is '${DATABASE_URL}'"
  fi
  export COVERAGE_PATH="cov_$(basename ${BUNDLE_GEMFILE%.gemfile})_${DATABASE_URL%:[:/]*}_ruby_${RUBY_VERSION}"
  export APPRAISAL_INITIALIZED=1 ;;
core)
  export COVERAGE_PATH="cov_core_ruby_${RUBY_VERSION}" ;;
lint)
  unset APPRAISAL_INITIALIZED ;;
*)
  echo "ERROR \$TEST_CONFIGURATION='${TEST_CONFIGURATION}' is unsupported " \
       "not in (libraries|rails|core|lint)" >&2
  exit 5 ;;
esac

echo -n "Configuration is '${TEST_CONFIGURATION}' on Ruby ${RUBY_VERSION} "
echo    "with dependencies in '${BUNDLE_GEMFILE}'"

# Update RubyGems
gem update --system > /dev/null
echo "Gem version $(gem --version)"

# List the built-in gem version of "net-http"
gem list | grep net-http

# Configure Bundler
bundler --version
bundle config set path '/tmp/vendor/bundle'

# Install Dependencies
bundle check || bundle install

# Run tests
if [[ "${TEST_CONFIGURATION}" = "lint" ]]; then
  bundle exec rubocop
else
  mkdir --parents "${COVERAGE_PATH}/_junit"
  bundle exec rake
fi
