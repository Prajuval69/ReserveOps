# frozen_string_literal: true

class Resource < ApplicationRecord
  belongs_to :location
  belongs_to :resource_category
  has_many :bookings, dependent: :restrict_with_exception
  has_many :resource_blackouts, dependent: :restrict_with_exception
  validates :name, :identifier, presence: true, length: { maximum: 150 }
  validates :identifier, uniqueness: { scope: :location_id }
  validates :occupants_capacity, :min_minutes, :max_minutes, :advance_days, numericality: { only_integer: true, greater_than: 0 }
  validates :opens_at, :closes_at, format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/ }
  validate do
    errors.add(:closes_at, 'must follow opening time; overnight hours are unsupported') if opens_at.to_s >= closes_at.to_s
    errors.add(:max_minutes, 'must be at least the minimum duration') if max_minutes.to_i < min_minutes.to_i
  end
end
