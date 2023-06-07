# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class GraphqlTest < Minitest::Test
  class TaskType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :action, String, null: false
  end

  class NewTaskType < GraphQL::Schema::Mutation
    argument :action, String, required: true
    field :task, TaskType, null: true

    def resolve(action:)
      {
        task: OpenStruct.new(id: '0', action: action)
      }
    end
  end

  class QueryType < GraphQL::Schema::Object
    field :tasks, TaskType.connection_type, null: false

    def tasks()
      [
        OpenStruct.new(id: '0', action: 'Sample 00'),
        OpenStruct.new(id: '1', action: 'Sample 01'),
        OpenStruct.new(id: '2', action: 'Sample 02'),
        OpenStruct.new(id: '3', action: 'Sample 03'),
        OpenStruct.new(id: '4', action: 'Sample 04')
      ]
    end
  end

  class MutationType < GraphQL::Schema::Object
    field :create_task, mutation: NewTaskType
  end

  class Schema < GraphQL::Schema
    query QueryType
    mutation MutationType
  end

  def test_it_works
    assert defined?(GraphQL)
  end

  def test_config_defaults
    assert ::Instana.config[:graphql].is_a?(Hash)
    assert ::Instana.config[:graphql].key?(:enabled)
    assert_equal true, ::Instana.config[:graphql][:enabled]
  end

  def test_query
    clear_all!

    query = "query FirstTwoTaskSamples {
      tasks(after: \"\", first: 2) {
        nodes {
          action
        }
      }
    }"

    expected_data = {
      :operationName => "FirstTwoTaskSamples",
      :operationType => "query",
      :arguments => { "tasks" => ["after", "first"] },
      :fields => { "tasks" => ["nodes"], "nodes" => ["action"] }
    }
    expected_results = {
      "data" => {
        "tasks" => {
          "nodes" => [{"action" => "Sample 00"}, {"action" => "Sample 01"}]
        }
      }
    }

    results = Instana.tracer.start_or_continue_trace('graphql-test') { Schema.execute(query) }
    query_span, root_span = *Instana.processor.queued_spans

    assert_equal expected_results, results.to_h
    assert_equal :sdk, root_span[:n]
    assert_equal :'graphql.server', query_span[:n]
    assert_equal expected_data, query_span[:data][:graphql]
  end

  def test_mutation
    clear_all!

    query = "mutation Sample {
      createTask(action: \"Sample\") {
        task {
          action
        }
      }
    }"

    expected_data = {
      :operationName => "Sample",
      :operationType => "mutation",
      :arguments => { "createTask" => ["action"] },
      :fields => { "createTask" => ["task"], "task" => ["action"] }
    }
    expected_results = {
      "data" => {
        "createTask" => {
          "task" => { "action" => "Sample" }
        }
      }
    }

    results = Instana.tracer.start_or_continue_trace('graphql-test') { Schema.execute(query) }
    query_span, root_span = *Instana.processor.queued_spans

    assert_equal expected_results, results.to_h
    assert_equal :sdk, root_span[:n]
    assert_equal :'graphql.server', query_span[:n]
    assert_equal expected_data, query_span[:data][:graphql]
  end
end
