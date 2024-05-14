#!/usr/bin/env bash

TEKTON_CI_OUT_FILE=resources/tekton-ci-output.txt

taskrun_list=$(kubectl get taskrun --sort-by=.metadata.creationTimestamp | grep -v "pr\|Failed\|currency")

declare -A pattern_map1=( ["cuba"]="1" ["excon"]="4" ["graphql"]="6" ["grpc"]="7" ["rack"]="10" ["rest-client"]="11" ["roda"]="13" ["sinatra"]="16" )

for library in "${!pattern_map1[@]}"
do
    pattern=${pattern_map1[$library]}

    successful_taskruns=( $(echo "${taskrun_list}" | awk -v pattern="${pattern}" '{ if ($1 ~ /unittest-default-ruby-33-'"$pattern"'$/) { print $1 } }' ) )
    # looping through the taskruns in reverse order to get the latest successful taskrun
    for ((i=${#successful_taskruns[@]}-1; i>=0; i--)); do
        pod_name=$(kubectl get taskrun "${successful_taskruns[$i]}" -o jsonpath='{.status.podName}')
        ci_output=$(kubectl logs ${pod_name} -c step-unittest | grep -o "Installing ${library} [^ ]*")
        if [ -n "${ci_output}" ]; then
            latest_successful_taskrun_output=${ci_output}
            break
        fi
    done
    echo ${latest_successful_taskrun_output} >> ${TEKTON_CI_OUT_FILE}
done

declare -A pattern_map2=( ["rails"]="rails-[[:alnum:]]*-11" ["dalli"]="memcached-11" ["resque"]="unittest-redis-ruby-32-33-9" ["sidekiq"]="unittest-redis-ruby-32-33-18" )

for library in "${!pattern_map2[@]}"
do
    pattern=${pattern_map2[$library]}

    successful_taskruns=( $(echo "${taskrun_list}" | awk -v pattern="${pattern}" '{ if ($0 ~ pattern) {print $1} }' ) )
    for ((i=${#successful_taskruns[@]}-1; i>=0; i--)); do
        pod_name=$(kubectl get taskrun "${successful_taskruns[$i]}" -o jsonpath='{.status.podName}')
        ci_output=$(kubectl logs ${pod_name} -c step-unittest | grep -o "Installing ${library} [^ ]*")
        if [ -n "${ci_output}" ]; then
            latest_successful_taskrun_output=${ci_output}
            break
        fi
    done
    echo ${latest_successful_taskrun_output} >> ${TEKTON_CI_OUT_FILE}
done
