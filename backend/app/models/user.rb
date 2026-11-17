# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  before_update do
    self.session_version += 1 if password_digest_changed? || (active_changed? && !active?)
  end
  has_many :manager_location_scopes, dependent: :destroy
  has_many :locations, through: :manager_location_scopes
  has_many :bookings, dependent: :restrict_with_exception
  has_many :notifications, dependent: :restrict_with_exception
  normalizes :email, with: ->(value) { value.strip.downcase }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :display_name, presence: true, length: { maximum: 100 }
  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :role, inclusion: { in: %w[employee manager admin] }
  def admin? = role == 'admin'
  def manager? = role == 'manager'
  def manages?(resource) = admin? || (manager? && locations.exists?(id: resource.location_id))
end
