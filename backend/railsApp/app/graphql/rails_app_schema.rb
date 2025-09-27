# frozen_string_literal: true

class RailsAppSchema < GraphQL::Schema
  query(Types::QueryType)
  mutation(Types::MutationType)
end
