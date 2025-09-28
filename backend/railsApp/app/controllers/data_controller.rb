class DataController < ApplicationController
  before_action :check_password

  def index
    render json: { message: "Authorized access to data!" }
  end

  private

  def check_password
    expected = 'q7V;{X$og<^);g{&THeaB07u+-4-NPs{Hm4uMn*~6'
    provided = request.headers['Password']

    unless ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end