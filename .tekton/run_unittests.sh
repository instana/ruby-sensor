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
  export TEST_SETUP="$(basename ${BUNDLE_GEMFILE%.gemfile})_ruby_${RUBY_VERSION}"
  export APPRAISAL_INITIALIZED=1 ;;
rails)
  if [[ -z "${DATABASE_URL}" ]]; then
    echo -n "The TEST_CONFIGURATION is set to ${TEST_CONFIGURATION}. " >&2
    echo    "But the DATABASE_URL environment variable is missing." >&2
    exit 4
  else
    echo "DATABASE_URL is '${DATABASE_URL}'"
  fi
  export TEST_SETUP="$(basename ${BUNDLE_GEMFILE%.gemfile})_${DATABASE_URL%:[:/]*}_ruby_${RUBY_VERSION}"
  export APPRAISAL_INITIALIZED=1 ;;
core)
  export TEST_SETUP="core_ruby_${RUBY_VERSION}" ;;
lint)
  export TEST_SETUP="lint_ruby_${RUBY_VERSION}" ;;
*)
  echo "ERROR \$TEST_CONFIGURATION='${TEST_CONFIGURATION}' is unsupported " \
       "not in (libraries|rails|core|lint)" >&2
  exit 5 ;;
esac

export COVERAGE_PATH="cov_${TEST_SETUP}"
export DEPENDENCY_PATH="dep_${TEST_SETUP}"

echo -n "Configuration is '${TEST_CONFIGURATION}' on Ruby ${RUBY_VERSION} "
echo    "with dependencies in '${BUNDLE_GEMFILE}'"

# The gemfiles folder is under the tekton shared workspace
# but we have to prevent the sharing, and the concurrent writing
# of the gemfiles/*.lock files
# so here we create a container-local, non-shared copy, of the sources and use that.
cp --recursive ../ruby-sensor/ /tmp/
pushd /tmp/ruby-sensor/
export WORKSPACE_PATH='/workspace/ruby-sensor'
# Update RubyGems

while ! gem update --system > /dev/null; do
  echo "Updating Gem with 'gem update --system' failed, retrying in a minute"
  break
done
echo "Gem version $(gem --version)"

# Configure Bundler
bundler --version
bundle config set path '/tmp/vendor/bundle'

ruby -r "${WORKSPACE_PATH}/.tekton/ibmcloud.rb" -e "IbmCloudStorageUtil.new.download_gem_bundle" || echo "failed to load gem bundle cache"

# Install Dependencies
while ! (bundle install) | tee "${DEPENDENCY_PATH}"; do
  echo "Bundle install failed, retrying in a minute"
  sleep 60
done

ruby -r "${WORKSPACE_PATH}/.tekton/ibmcloud.rb" -e "IbmCloudStorageUtil.new.upload_gem_bundle" || echo "failed to upload gem bundle cache"

# Run tests
if [[ "${TEST_CONFIGURATION}" = "lint" ]]; then
  bundle exec rubocop
else
  mkdir --parents "${COVERAGE_PATH}/_junit"
  bundle exec rake
  cp --recursive "${COVERAGE_PATH}" "${OLDPWD}/"
fi

# Put back the dependency insallation results to the shared workspace
cp --recursive "${DEPENDENCY_PATH}" "${OLDPWD}/"
popd
