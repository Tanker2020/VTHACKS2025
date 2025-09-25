class HomeController < ApplicationController
  def index
    render plain: "Hello from Rails 👋"
    # or: render json: { ok: true }
  end
end