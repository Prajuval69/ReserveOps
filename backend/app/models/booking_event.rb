# frozen_string_literal: true

class BookingEvent < ApplicationRecord
  belongs_to :booking
  belongs_to :actor, class_name: 'User', optional: true
  validates :action, presence: true
  before_update { throw :abort }
  before_destroy { throw :abort }
end
