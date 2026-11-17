# frozen_string_literal: true

class WaitlistPromotionJob
  include Sidekiq::Job

  sidekiq_options retry: 5
  def perform(resource_id)
    WaitlistPromoter.call(resource_id) if Resource.exists?(resource_id)
  end
end
