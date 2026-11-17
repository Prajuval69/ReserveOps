# frozen_string_literal: true

class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  rescue_from DomainError, with: :domain_error
  rescue_from ActiveRecord::RecordInvalid do |e|
    domain_error(DomainError.new(e.record.errors.full_messages.join(', '), details: e.record.errors.to_hash))
  end
  rescue_from ActiveRecord::RecordNotFound do
    domain_error(DomainError.new('Record not found.', code: 'NOT_FOUND', status: 404))
  end
  rescue_from ActionController::InvalidAuthenticityToken do
    domain_error(DomainError.new('Session security token is invalid. Refresh and try again.', code: 'INVALID_CSRF', status: 403))
  end
  rescue_from ActionController::ParameterMissing, ArgumentError do |e|
    domain_error(DomainError.new(e.message, code: 'BAD_REQUEST', status: 400))
  end

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id], session_version: session[:session_version], active: true)
  end

  def authenticate_user!
    raise DomainError.new('Sign in to continue.', code: 'UNAUTHENTICATED', status: 401) unless current_user
  end

  def admin!
    raise DomainError.new('Administrator access required.', code: 'FORBIDDEN', status: 403) unless current_user.admin?
  end

  def domain_error(error)
    render json: { error: { code: error.code, message: error.message, details: error.details }, request_id: request.request_id }, status: error.status
  end

  def collection(scope, &)
    page = [params.fetch(:page, 1).to_i, 1].max
    size = params.fetch(:per_page, 24).to_i.clamp(1, 100)
    { data: scope.limit(size).offset((page - 1) * size).map(&), meta: { page: page, per_page: size, total: scope.count } }
  end

  def serialize_user(user)
    user.as_json(only: %i[id email display_name role]).merge(location_ids: user.location_ids, timezone: Rails.application.config.time_zone)
  end

  def serialize_resource(resource)
    resource.as_json.merge(location: resource.location.as_json, category: resource.resource_category.as_json)
  end

  def serialize_booking(booking, timeline: false)
    data = booking.as_json.merge(resource: serialize_resource(booking.resource))
    data[:events] = booking.booking_events.order(:created_at, :id).as_json if timeline
    data
  end
end
