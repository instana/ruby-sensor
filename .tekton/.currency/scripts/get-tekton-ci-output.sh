#!/bin/bash

TEKTON_CI_OUT_FILE=utils/tekton-ci-output.txt

# Empty the file
>$TEKTON_CI_OUT_FILE

taskrun_list=$(tkn taskrun list)

pattern_library_map=("1:cuba" "4:excon" "6:graphql" "7:grpc" "10:rack" "11:rest-client" "13:roda" "16:sinatra")
for pattern_library in ${pattern_library_map[@]}
do
    pattern=$(echo "${pattern_library}" | awk -F':' '{print $1}')
    library=$(echo "${pattern_library}" | awk -F':' '{print $2}')

    latest_successful_taskrun=$(echo "${taskrun_list}" | grep "unittest-default-ruby-33-${pattern}\s" | head -n 1 | awk '{print $1}')
    tkn taskrun logs ${latest_successful_taskrun} | grep -o "Installing ${library} [^ ]*" >> ${TEKTON_CI_OUT_FILE}
done

library_pattern_map=("rails:rails-\w*-11" "dalli:memcached-11" "resque:unittest-redis-ruby-32-33-9" "sidekiq:unittest-redis-ruby-32-33-18")

for library_pattern in ${library_pattern_map[@]}
do
    library=$(echo "${library_pattern}" | awk -F':' '{print $1}')
    pattern=$(echo "${library_pattern}" | awk -F':' '{print $2}')

    latest_successful_taskrun=$(echo "${taskrun_list}" | grep "${pattern}" | head -n 1 | awk '{print $1}')
    tkn taskrun logs ${latest_successful_taskrun} | grep -o "Installing ${library} [^ ]*" >> ${TEKTON_CI_OUT_FILE}
done
