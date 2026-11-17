# frozen_string_literal: true

class Booking < ApplicationRecord
  STATUSES = %w[pending_approval confirmed waitlisted rejected cancelled expired completed].freeze
  ACTIVE = %w[pending_approval confirmed].freeze
  TRANSITIONS = {
    'confirmed' => %w[pending_approval cancelled completed],
    'pending_approval' => %w[confirmed rejected cancelled expired],
    'waitlisted' => %w[confirmed pending_approval cancelled expired]
  }.freeze
  belongs_to :user
  belongs_to :resource
  belongs_to :approved_by, class_name: 'User', optional: true
  has_many :booking_events, dependent: :restrict_with_exception
  has_many :notifications, dependent: :restrict_with_exception
  scope :blocking, -> { where(status: ACTIVE) }
  scope :overlapping, ->(from, to) { where('starts_at < ? AND ends_at > ?', to, from) }
  validates :status, inclusion: { in: STATUSES }
  validates :purpose, presence: true, length: { maximum: 250 }
  validates :attendee_count, numericality: { only_integer: true, greater_than: 0 }
  validates :starts_at, :ends_at, presence: true
  validate do
    errors.add(:ends_at, 'must follow start') unless starts_at && ends_at && ends_at > starts_at
    errors.add(:attendee_count, 'exceeds capacity') if resource && attendee_count.to_i > resource.occupants_capacity
    errors.add(:status, 'cannot complete before the end') if status == 'completed' && ends_at && ends_at > Time.current
    errors.add(:status, 'transition is not allowed') if persisted? && will_save_change_to_status? && !Array(TRANSITIONS[status_in_database]).include?(status)
    if persisted? && (will_save_change_to_starts_at? || will_save_change_to_ends_at?) && starts_at_in_database <= Time.current
      errors.add(:base, 'Started bookings cannot be rescheduled')
    end
  end
  before_update do
    if status_in_database.in?(%w[cancelled rejected expired completed])
      errors.add(:base, 'Final booking records are immutable')
      throw :abort
    end
  end
  before_destroy { throw :abort }
  after_commit :schedule_lifecycle, on: %i[create update]
  def schedule_lifecycle
    LifecycleScheduler.call(self)
  end
end
