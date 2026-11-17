# frozen_string_literal: true

class ResourceBlackout < ApplicationRecord
  belongs_to :resource
  validates :starts_at, :ends_at, :reason, presence: true
  validate { errors.add(:ends_at, 'must follow start') unless starts_at && ends_at && ends_at > starts_at }
end
