# frozen_string_literal: true

module Api
  module V1
    class CatalogController < ApplicationController
      def categories = render(json: { data: ResourceCategory.order(:name) })
      def locations = render(json: { data: (current_user.admin? ? Location.all : Location.where(active: true)).order(:name) })

      def destroy_category
        admin!
        category = ResourceCategory.find(params[:id])
        raise DomainError.new('Move resources to another category before deleting it.', code: 'CATEGORY_IN_USE', status: 409) if category.resources.exists?

        category.destroy!
        head :no_content
      end

      def destroy_location
        admin!
        Location.find(params[:id]).update!(active: false)
        head :no_content
      end

      def create_category
        admin!
        render json: { data: ResourceCategory.create!(params.require(:category).permit(:name, :slug)) }, status: :created
      end

      def update_category
        admin!
        category = ResourceCategory.find(params[:id])
        category.update!(params.require(:category).permit(:name, :slug))
        render json: { data: category }
      end

      def create_location
        admin!
        render json: { data: Location.create!(params.require(:location).permit(:name, :timezone, :active)) }, status: :created
      end

      def update_location
        admin!
        location = Location.find(params[:id])
        location.update!(params.require(:location).permit(:name, :timezone, :active))
        render json: { data: location }
      end

      def users
        admin!
        render json: collection(User.order(:display_name)) { |u| serialize_user(u).merge(active: u.active) }
      end

      def assign_manager
        admin!
        user = User.find(params[:user_id])
        ids = Array(params[:location_ids]).map(&:to_i).uniq
        raise DomainError, 'Only managers or admins can have management scopes.' unless user.manager? || user.admin?
        raise DomainError, 'Unknown location.' unless Location.where(id: ids).count == ids.length

        user.with_lock do
          user.manager_location_scopes.destroy_all
          ids.each { |id| user.manager_location_scopes.create!(location_id: id) }
        end
        render json: { data: serialize_user(user.reload) }
      end
    end
  end
end
