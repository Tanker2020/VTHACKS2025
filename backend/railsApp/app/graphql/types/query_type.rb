# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    description "The root query type for the application"

    field :sanity_check, String, null: false, description: "Returns a static string to verify GraphQL wiring"

    field :profile, Types::ProfileType, null: true do
      description "Fetch a user's profile by their UUID"
      argument :uuid, String, required: true

    end

    def sanity_check
      "GraphQL endpoint is live, and Data: #{}"
    end


  end
end
