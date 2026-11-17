# frozen_string_literal: true

class ResourceCategory < ApplicationRecord
  has_many :resources, dependent: :restrict_with_exception
  validates :name, :slug, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
end
