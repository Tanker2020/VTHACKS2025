# frozen_string_literal: true

module Auth
  # Raised when JWT verification fails and access should be denied with 403.
  class ForbiddenError < StandardError
    def initialize(message = "Forbidden Access")
      super
    end
  end
end
