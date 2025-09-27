class ErrorsController < ApplicationController
  # Return a JSON payload for unmatched routes
  def not_found
    render json: { error: 'no endpoint found' }, status: :not_found
  end
end
