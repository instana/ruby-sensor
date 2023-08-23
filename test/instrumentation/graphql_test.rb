# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class GraphqlTest < Minitest::Test
  class TaskType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :action, String, null: false
  end

  class JobType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: false
  end

  class TaskJobUnion < GraphQL::Schema::Union
    description "A union type for Task and Job"
    possible_types TaskType, JobType

    def self.resolve_type(object, _context)
      if !object.action.nil?
        TaskType
      elsif !object.description?
        JobType
      else
        raise("Unexpected object: #{object}")
      end
    end
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
    field :jobs, JobType.connection_type, null: false
    field :tasksorjobs, TaskJobUnion.connection_type, null: false

    def tasks()
      [
        OpenStruct.new(id: '0', action: 'Sample 00'),
        OpenStruct.new(id: '1', action: 'Sample 01'),
        OpenStruct.new(id: '2', action: 'Sample 02'),
        OpenStruct.new(id: '3', action: 'Sample 03'),
        OpenStruct.new(id: '4', action: 'Sample 04')
      ]
    end

    def jobs()
      [
        OpenStruct.new(id: '0', name: 'Name 00', description: 'Desc 00'),
        OpenStruct.new(id: '1', name: 'Name 01', description: 'Desc 01'),
        OpenStruct.new(id: '2', name: 'Name 02', description: 'Desc 02'),
        OpenStruct.new(id: '3', name: 'Name 03', description: 'Desc 03'),
        OpenStruct.new(id: '4', name: 'Name 04', description: 'Desc 04')
      ]
    end

    def tasksorjobs()
      [
        OpenStruct.new(id: '0', action: 'Task 00'),
        OpenStruct.new(id: '0', name: 'Job 00', description: 'Job Desc 00')
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

    activator = ::Instana::Activators::GraphqL.new
    assert_equal true, activator.can_instrument?
  end

  def test_instrumentation_disabled
    ::Instana.config[:graphql][:enabled] = false

    activator = ::Instana::Activators::GraphqL.new
    assert_equal false, activator.can_instrument?
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

  def test_query_with_fragment
    clear_all!

    query = "
    fragment actionDetails on Task {
      action
    }

    query SampleWithFragment {
      tasks {
        nodes {
          ... actionDetails
        }
      }
    }"

    expected_data = {
      :operationName => "SampleWithFragment",
      :operationType => "query",
      :arguments => {},
      :fields => { "tasks" => ["nodes"], "nodes" => ["actionDetails"] }
    }
    expected_results = {
      "data" => {
        "tasks" => {
          "nodes" => [{"action" => "Sample 00"}, {"action" => "Sample 01"},
                      {"action" => "Sample 02"}, {"action" => "Sample 03"},
                      {"action" => "Sample 04"}]
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

  def test_query_union_with_fragment
    clear_all!

    query = "
    query QueryUnionWithFragment {
      tasksorjobs {
        nodes {
          ... on Task {
            action
          }
          ... on Job {
            name
            description
          }
        }
      }
    }"

    expected_data = {
      :operationName => "QueryUnionWithFragment",
      :operationType => "query",
      :arguments => {},
      :fields => { "tasksorjobs" => ["nodes"],
                   "nodes" => ["InlineFragment", "InlineFragment"],
                   "InlineFragment" => %w[action name description]}
    }
    expected_results = {
      "data" => {
        "tasksorjobs" => {
          "nodes" => [{"action" => "Task 00"},
                      {"name" => "Job 00", "description" => "Job Desc 00"}]
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
