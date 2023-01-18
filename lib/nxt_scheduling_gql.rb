require "graphql/client"
require "graphql/client/http"

class NxtSchedulingGql
  class QueryCallerWrapper
    def initialize(query_definition)
      @query_definition = query_definition
    end

    def call(vars = {})
      variables = vars.deep_transform_keys { |k| k.to_s.camelize(:lower) }
      query_result = NxtSchedulingGql.client.query(@query_definition, variables:)
      response = response_path.reduce(query_result.to_h) { |acc, k| acc[k] }
      return response.map { |item| item.deep_transform_keys(&:underscore) } if response.is_a?(::Array)

      response.deep_transform_keys(&:underscore)
    end

    private

    def response_path
      @response_path ||= begin
        k1 = @query_definition.schema_class.defined_fields.keys.first
        k2_class = @query_definition.schema_class.defined_fields[k1]
        k2_class = k2_class.of_klass until k2_class.respond_to?(:defined_fields)
        k2 = k2_class.defined_fields.keys.first
        ["data", k1, k2]
      end
    end
  end

  class << self
    def http_client
      @http_client ||= ::GraphQL::Client::HTTP.new(ENV.fetch("SCHEDULING_BACK_GQL_URL"))
    end

    def schema
      @schema ||= ::GraphQL::Client.load_schema(http_client)
    end

    def client
      @client ||= begin
        result = ::GraphQL::Client.new(schema: schema, execute: http_client)
        result.allow_dynamic_queries = true
        result
      end
    end

    def parse_query(query)
      definition = NxtSchedulingGql.client.parse(query)
      QueryCallerWrapper.new(definition)
    end
  end
end