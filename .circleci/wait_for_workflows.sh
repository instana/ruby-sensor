#!/usr/bin/env bash
set -e

if [[ -z "${CIRCLE_TOKEN:-}" ]]; then
  echo "WARNING: CIRCLE_TOKEN is not set. Skipping waiting for sibling workflows."
  exit 0
fi

PROJECT_SLUG='https://circleci.com/api/v2/project/gh/instana/ruby-sensor'
PIPELINE_SLUG='https://circleci.com/api/v2/pipeline'
WORKFLOW_SLUG='https://circleci.com/api/v2/workflow'

echo "=== Getting Pipeline ID for build #${CIRCLE_BUILD_NUM} ==="
PIPELINE_ID=$(curl -s \
  -H "Circle-Token: ${CIRCLE_TOKEN}" \
  "${PROJECT_SLUG}/job/${CIRCLE_BUILD_NUM}" \
  | jq -rj '.pipeline.id // empty')

if [[ -z "${PIPELINE_ID}" ]]; then
  echo "WARNING: Could not retrieve PIPELINE_ID from job info. Proceeding."
  exit 0
fi

echo "Pipeline ID: ${PIPELINE_ID}"

echo "=== Querying workflows for pipeline ==="
WORKFLOW_INFO=$(curl -sf \
  -H "Circle-Token: ${CIRCLE_TOKEN}" \
  "${PIPELINE_SLUG}/${PIPELINE_ID}/workflow" \
  | jq -r '.items[] | select(.name != "core" and .name != "report_coverage" and .name != "publish") | "\(.id)\t\(.name)"')

echo "Discovered test workflows to wait for:"
echo "${WORKFLOW_INFO}"
echo ""

# Loop and wait until every sibling workflow reaches a terminal state
while IFS=$'\t' read -r workflow_id workflow_name; do
  [[ -z "${workflow_id}" ]] && continue

  echo "Waiting for workflow '${workflow_name}' (${workflow_id}) to complete..."
  MAX_ATTEMPTS=120  # up to 30 mins (120 * 15s)
  ATTEMPT=0
  while [[ ${ATTEMPT} -lt ${MAX_ATTEMPTS} ]]; do
    STATUS=$(curl -s \
      -H "Circle-Token: ${CIRCLE_TOKEN}" \
      "${WORKFLOW_SLUG}/${workflow_id}" \
      | jq -r '.status // "unknown"')
    
    if [[ "${STATUS}" != "running" && "${STATUS}" != "on_hold" && "${STATUS}" != "unknown" ]]; then
      echo "  ✓ Workflow '${workflow_name}' finished with status: ${STATUS}"
      break
    fi

    echo "  ... '${workflow_name}' is currently: ${STATUS} (waiting 15s, attempt $((ATTEMPT+1))/${MAX_ATTEMPTS})"
    sleep 15
    ATTEMPT=$((ATTEMPT + 1))
  done
done <<< "${WORKFLOW_INFO}"

echo ""
echo "=== All sibling test workflows have finished (including auto-retries) ==="
