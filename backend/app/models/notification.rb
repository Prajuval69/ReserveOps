# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :booking, optional: true
  validates :notification_key, :title, :kind, :body, presence: true
  def self.deliver(user:, key:, title:, body:, kind:, booking: nil)
    create_or_find_by!(user: user, notification_key: key) do |n|
      n.assign_attributes(title: title, body: body, kind: kind, booking: booking)
    end
  end
end
