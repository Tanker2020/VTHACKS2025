# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    description "The root query type for the application"

    field :sanity_check, String, null: false, description: "Returns a static string to verify GraphQL wiring"

    def sanity_check
      "GraphQL endpoint is live"
    end
  end
end
