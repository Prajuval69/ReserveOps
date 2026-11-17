# frozen_string_literal: true

class ManagerLocationScope < ApplicationRecord
  belongs_to :user
  belongs_to :location
  validates :location_id, uniqueness: { scope: :user_id }
  validate { errors.add(:user, 'must be a manager or admin') unless user&.manager? || user&.admin? }
end
