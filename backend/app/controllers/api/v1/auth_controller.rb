# frozen_string_literal: true

module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[csrf login]
      def csrf
        render json: { data: { csrf_token: form_authenticity_token } }
      end

      def login
        # Local persistent-process rate limiter; production must use a shared cache.
        key = "login:#{request.remote_ip}"
        attempts = Rails.cache.read(key).to_i
        raise DomainError.new('Too many login attempts. Try again in 5 minutes.', code: 'RATE_LIMITED', status: 429) if attempts >= 10

        Rails.cache.write(key, attempts + 1, expires_in: 5.minutes)
        user = User.find_by(email: params[:email].to_s.strip.downcase, active: true)
        raise DomainError.new('Email or password is incorrect.', code: 'INVALID_CREDENTIALS', status: 401) unless user&.authenticate(params[:password].to_s)

        reset_session
        session[:user_id] = user.id
        session[:session_version] = user.session_version
        Rails.cache.delete(key)
        render json: { data: serialize_user(user), csrf_token: form_authenticity_token }
      end

      def logout
        current_user.increment!(:session_version)
        reset_session
        head :no_content
      end

      def me
        render json: { data: serialize_user(current_user) }
      end
    end
  end
end
