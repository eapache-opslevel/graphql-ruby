# frozen_string_literal: true
require "spec_helper"

describe GraphQL::Tracing::ActiveSupportNotificationsTracing do
  let(:schema) {
    Class.new(StarWars::Schema) do
      tracer GraphQL::Tracing::ActiveSupportNotificationsTracing
    end
  }

  it "pushes through AS::N" do
    traces = []

    callback = ->(name, started, finished, id, data) {
      path_str = if TESTING_INTERPRETER
        if data.key?(:field)
          " (#{data[:field].path})"
        else
          ""
        end
      else
        if data.key?(:context)
          " (#{data[:context].irep_node.owner_type}.#{data[:context].field.name})"
        else
          ""
        end
      end
      traces << "#{name}#{path_str}"
    }

    query_string = <<-GRAPHQL
    query Bases($id1: ID!, $id2: ID!){
      b1: batchedBase(id: $id1) { name }
      b2: batchedBase(id: $id2) { name }
    }
    GRAPHQL
    first_id = StarWars::Base.first.id
    last_id = StarWars::Base.last.id

    ActiveSupport::Notifications.subscribed(callback, /graphql$/) do
      schema.execute(query_string, variables: {
        "id1" => first_id,
        "id2" => last_id,
      })
    end

    expected_traces = [
      "lex.graphql",
      "parse.graphql",
      "validate.graphql",
      "analyze_query.graphql",
      "analyze_multiplex.graphql",
      (TESTING_INTERPRETER ? "authorized.graphql" : nil),
      "execute_field.graphql (Query.batchedBase)",
      "execute_field.graphql (Query.batchedBase)",
      "execute_query.graphql",
      "lazy_loader.graphql",
      "execute_field_lazy.graphql (Query.batchedBase)",
      (TESTING_INTERPRETER ? "authorized.graphql" : nil),
      "execute_field.graphql (Base.name)",
      "execute_field_lazy.graphql (Query.batchedBase)",
      (TESTING_INTERPRETER ? "authorized.graphql" : nil),
      "execute_field.graphql (Base.name)",
      "execute_field_lazy.graphql (Base.name)",
      "execute_field_lazy.graphql (Base.name)",
      "execute_query_lazy.graphql",
      "execute_multiplex.graphql",
    ].compact
    assert_equal expected_traces, traces
  end
end
