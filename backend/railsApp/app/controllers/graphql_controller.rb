# frozen_string_literal: true

class GraphqlController < ApplicationController
  # If accessing from outside this domain, nullify the session
  # This allows for outside API access while preventing CSRF attacks,
  # but you'll have to authenticate your user separately
  protect_from_forgery with: :null_session

  # Main entry point for GraphQL queries and mutations.
  #
  # This controller enforces authentication by verifying a JWT supplied
  # either in an Authorization header or, for the authenticate mutation,
  # in the GraphQL variables payload. The decoded token payload is cached
  # in Redis until expiry to avoid repeated cryptographic verification.
  # Every resolver can access the decoded payload via context and decide
  # on granular authorization if needed, while the controller guards ingress.
  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]

    token = extract_token(query, variables)
    payload = authenticate_token!(token)

    context = {
      jwt_payload: payload,
      raw_jwt: token
    }

    result = RailsAppSchema.execute(query, variables:, context:, operation_name:)
    status_code = context.delete(:http_status) || :ok
    render json: result, status: status_code
  rescue Auth::ForbiddenError => e
    render json: { errors: [{ message: e.message }] }, status: :forbidden
  rescue StandardError => e
    raise e unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  # GraphQL variables can arrive in multiple formats, so normalize them here.
  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? JSON.parse(variables_param) : {}
    when ActionController::Parameters
      variables_param.permit!.to_h
    when nil
      {}
    when Hash
      variables_param
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  # Extract the JWT from the Authorization header first, then fall back to
  # a token supplied in the GraphQL variables when the authenticate mutation runs.
  def extract_token(query, variables)
    # Dev-only: allow a special admin bearer token to bypass normal JWT verification.
    # Set DEV_ADMIN_BEARER_TOKEN in your env (for example in backend/.env.dev) to enable.
    if dev_admin_bearer_token_present?
      return dev_admin_bearer_token_value
    end

    if authenticate_field_requested?(query)
      # Allow the authenticate mutation to validate a token supplied via variables,
      # which keeps the onboarding flow simple before clients persist the header.
      supplied_token = variables.with_indifferent_access[:token]
      return supplied_token if supplied_token.present?
    end

    header_token = bearer_token_from_header
    return header_token if header_token.present?

    nil
  end

  # Pull the token from an Authorization header that follows the "Bearer" scheme.
  def bearer_token_from_header
    auth_header = request.headers["Authorization"].to_s
    return if auth_header.blank?

    scheme, token = auth_header.split(" ", 2)
    scheme&.casecmp?("Bearer") ? token : nil
  end

  # Dev helper: check if the request presents the special development admin token.
  def dev_admin_bearer_token_present?
    return false unless Rails.env.development?
    header = bearer_token_from_header
    return false if header.blank?

    dev_token = ENV["DEV_ADMIN_BEARER_TOKEN"] || "dev-admin"
    # Use secure_compare when possible to avoid timing attacks even in dev.
    ActiveSupport::SecurityUtils.secure_compare(header, dev_token)
  rescue StandardError
    # If secure_compare fails for length mismatch or other oddities, fall back to ==
    header == (ENV["DEV_ADMIN_BEARER_TOKEN"] || "dev-admin")
  end

  def dev_admin_bearer_token_value
    ENV["DEV_ADMIN_BEARER_TOKEN"] || "dev-admin"
  end

  # Use the GraphQL parser so we only trust requests that explicitly ask
  # for the authenticate field when accepting tokens from the variables payload.
  def authenticate_field_requested?(query)
    return false if query.blank?

    document = GraphQL.parse(query)
    document.definitions.any? do |definition|
      next unless definition.is_a?(GraphQL::Language::Nodes::OperationDefinition)

      definition.selections.any? { |selection| selection.name == "authenticate" }
    end
  rescue GraphQL::ParseError
    false
  end

  # Verify the token signature, enforce the expiry, and memoize the payload in Redis.
  def authenticate_token!(token)
    raise Auth::ForbiddenError if token.blank?

    # Dev shortcut: if the token matches the configured DEV_ADMIN_BEARER_TOKEN
    # and we're running in development, return a synthetic admin payload so
    # local testing can bypass real JWT verification.
    if Rails.env.development? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, dev_admin_bearer_token_value)
      return {
        "sub" => "dev-admin",
        "role" => "admin",
        # set an expiry far in the future (year 3000) to avoid immediate expiry checks
        "exp" => 32503680000
      }
    end

    cached_payload = Auth::TokenCache.fetch(token)
    return cached_payload if cached_payload && token_fresh?(cached_payload)

    resolved_payload = Auth::JwtVerifier.verify!(token)
    Auth::TokenCache.store(token, resolved_payload, resolved_payload.fetch("exp"))
    resolved_payload
  rescue Auth::ForbiddenError
    Auth::TokenCache.delete(token) if token.present?
    raise
  end

  # Guard against the edge case where a stale payload still exists in Redis.
  def token_fresh?(payload)
    expiration_epoch = payload["exp"].to_i
    return false if expiration_epoch.zero?

    expiration_epoch > Time.now.to_i
  end

  def handle_error_in_development(error)
    logger.error(error.message)
    logger.error(error.backtrace.join("\n"))

    render json: { errors: [{ message: error.message, backtrace: error.backtrace }], data: {} }, status: :internal_server_error
  end
end
