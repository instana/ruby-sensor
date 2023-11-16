#!/usr/bin/env bash

if [[ -z ${CIRCLE_TOKEN} ]]
then
    echo "ERROR: The CIRCLE_TOKEN variable is missing"
    exit 255
fi

PROJECT_SLUG='https://circleci.com/api/v2/project/gh/instana/ruby-sensor'
PIPELINE_SLUG='https://circleci.com/api/v2/pipeline/'
WORKFLOW_SLUG='https://circleci.com/api/v2/workflow/'

echo "Getting Pipeline ID"
PIPELINE_ID=$(curl -s \
                   -H "Circle-Token: ${CIRCLE_TOKEN}" \
                   "${PROJECT_SLUG}/job/${CIRCLE_BUILD_NUM}" \
              | jq -rj '.pipeline.id')


echo "Received Pipeline ID is: ${PIPELINE_ID}"

echo "Getting Workflows for Pipeline ID"
WORKFLOW_IDS=$(curl -s \
                    -H "Circle-Token: ${CIRCLE_TOKEN}" \
                    "${PIPELINE_SLUG}/${PIPELINE_ID}/workflow" \
              | jq -r '.items[] | select(.name!="report_coverage") | .id')

echo "Received Workflow IDs are: ${WORKFLOW_IDS}"

for workflow_id in ${WORKFLOW_IDS}
do
    echo "Waiting for workflow ${workflow_id} to finish"
    while true
    do
        STATUS=$(curl -s \
                      -H "Circle-Token: ${CIRCLE_TOKEN}" \
                      "${WORKFLOW_SLUG}/${workflow_id}" \
                | jq -r '.status')
        if [[ ${STATUS} != "running" && ${STATUS} != "on_hold" ]]
        then
            break
        else
            echo "Workflow ${workflow_id} has not finished yet. Status is: ${STATUS}"
            sleep 10
        fi
    done

    if [[ "${STATUS}" != "success" ]]
    then
        echo "ERROR: Workflow ${workflow_id} did not succeed! Status is: ${STATUS}"
        exit 254
    else
        echo "Workflow ${workflow_id} has finished successfully! Status is: ${STATUS}"
    fi
done


echo "All workflows have successfully finished, downloading artifacts."

mkdir partial_coverage_results
for workflow_id in ${WORKFLOW_IDS}
do
    JOB_NUMBERS=$(curl -s \
                       -H "Circle-Token: ${CIRCLE_TOKEN}" \
                       "${WORKFLOW_SLUG}/${workflow_id}/job" \
                 | jq -r '.items[] | .job_number' \
                 | tr '\n' ' ')

    for job in ${JOB_NUMBERS}
    do
        ARTIFACT_DOWNLOAD_LINK=$(curl -s \
                                      -H "Circle-Token: ${CIRCLE_TOKEN}" \
                                     "${PROJECT_SLUG}/${job}/artifacts" \
                                 | jq -r \
                                      '.items[] | select(.path=="coverage/.resultset.json") | .url')
                                      #'.items[] | select(.path=="coverage/coverage.json" or .path=="coverage/.resultset.json") | .url')
        curl -s \
             -L \
             -H "Circle-Token: ${CIRCLE_TOKEN}" \
             "${ARTIFACT_DOWNLOAD_LINK}" \
             -o partial_coverage_results/.resultset-${job}.json
    done
done

echo "All artifacts have been successfully downloaded."
