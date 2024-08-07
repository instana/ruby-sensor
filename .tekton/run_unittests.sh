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

# The gemfiles folder is under the tekton shared workspace
# but we have to prevent the sharing, and the concurrent writing
# of the gemfiles/*.lock files
# so here we create a container-local, non-shared copy, of the sources and use that.
cp --recursive ../ruby-sensor/ /tmp/
pushd /tmp/ruby-sensor/

# Update RubyGems
gem update --system > /dev/null
echo "Gem version $(gem --version)"

# Configure Bundler
bundler --version
bundle config set path '/tmp/vendor/bundle'

# Install Dependencies
while ! (bundle check || bundle install); do
  echo "Bundle install failed, retrying in a minute"
  sleep 60
done

# Run tests
if [[ "${TEST_CONFIGURATION}" = "lint" ]]; then
  bundle exec rubocop
else
  mkdir --parents "${COVERAGE_PATH}/_junit"
  bundle exec rake
fi

# Put back the coverage results to the shared workspace
popd
cp --recursive "${OLDPWD}/${COVERAGE_PATH}" ./
