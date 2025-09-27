# frozen_string_literal: true

module Types
  class AuthPayloadType < Types::BaseObject
    description "Provides metadata about a validated Supabase JWT"

    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false,
          description: "UTC timestamp for when the supplied JWT expires"
  end
end
