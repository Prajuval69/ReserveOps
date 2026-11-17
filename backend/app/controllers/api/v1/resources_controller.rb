# frozen_string_literal: true

module Api
  module V1
    class ResourcesController < ApplicationController
      before_action :admin!, only: %i[create update destroy create_blackout]
      def index
        scope = Resource.includes(:location, :resource_category).order(:name)
        scope = scope.where(active: true).joins(:location).where(locations: { active: true }) unless current_user.admin? && params[:all] == 'true'
        scope = scope.where(resource_category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.where(location_id: params[:location_id]) if params[:location_id].present?
        scope = scope.where('resources.name ILIKE ?', "%#{Resource.sanitize_sql_like(params[:q])}%") if params[:q].present?
        render json: collection(scope) { |r| serialize_resource(r) }
      end

      def show
        render json: { data: serialize_resource(find_resource) }
      end

      def create
        resource = Resource.create!(resource_params)
        render json: { data: serialize_resource(resource) }, status: :created
      end

      def update
        resource = Resource.find(params[:id])
        resource.with_lock { resource.update!(resource_params) }
        render json: { data: serialize_resource(resource) }
      end

      def availability
        resource = find_resource
        from = TimeInput.parse(params[:from])
        to = TimeInput.parse(params[:to])
        raise DomainError, 'Choose a positive calendar window up to 31 days.' unless to > from && to - from <= 31.days

        intervals = resource.bookings.blocking.overlapping(from, to).order(:starts_at).map { |b| b.as_json(only: %i[starts_at ends_at status]) }
        blackouts = resource.resource_blackouts.where('starts_at < ? AND ends_at > ?', to, from).as_json(only: %i[starts_at ends_at reason])
        render json: { data: { intervals: intervals, blackouts: blackouts, timezone: resource.location.timezone, opens_at: resource.opens_at,
                               closes_at: resource.closes_at } }
      end

      def destroy
        resource = Resource.find(params[:id])
        resource.with_lock { resource.update!(active: false) }
        render json: { data: serialize_resource(resource) }
      end

      def blackouts
        render json: collection(find_resource.resource_blackouts.order(:starts_at), &:as_json)
      end

      def create_blackout
        resource = Resource.find(params[:id])
        blackout = nil
        resource.with_lock do
          attrs = params.require(:blackout).permit(:starts_at, :ends_at, :reason).to_h.symbolize_keys
          attrs[:starts_at] = TimeInput.parse(attrs[:starts_at])
          attrs[:ends_at] = TimeInput.parse(attrs[:ends_at])
          if resource.bookings.blocking.overlapping(attrs[:starts_at], attrs[:ends_at]).exists?
            raise DomainError.new('Move or cancel active reservations before adding maintenance.', code: 'BLACKOUT_CONFLICT', status: 409)
          end

          blackout = resource.resource_blackouts.create!(attrs)
        end
        render json: { data: blackout }, status: :created
      end

      private

      def find_resource
        scope = current_user.admin? ? Resource.all : Resource.where(active: true)
        scope.find(params[:id])
      end

      def resource_params
        params.require(:resource).permit(:name, :identifier, :description, :resource_category_id, :location_id, :occupants_capacity,
                                         :requires_approval, :min_minutes, :max_minutes, :advance_days, :opens_at, :closes_at, :active)
      end
    end
  end
end
