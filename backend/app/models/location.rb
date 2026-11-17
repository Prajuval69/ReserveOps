# frozen_string_literal: true

class Location < ApplicationRecord
  has_many :resources, dependent: :restrict_with_exception
  validates :name, presence: true, uniqueness: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:identifier) }
end
