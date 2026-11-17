# frozen_string_literal: true

class BookingPolicy
  def self.scope(user)
    return Booking.all if user.admin?
    return Booking.where(user_id: user.id).or(Booking.where(resource_id: Resource.where(location_id: user.location_ids))) if user.manager?

    Booking.where(user_id: user.id)
  end

  def self.decide!(user, booking)
    return if user.manages?(booking.resource) && user.id != booking.user_id

    raise DomainError.new('A scoped manager other than the requester must decide.', code: 'FORBIDDEN', status: 403)
  end

  def self.modify!(user, booking, owner_only: false)
    allowed = booking.user_id == user.id || (!owner_only && user.manages?(booking.resource))
    raise DomainError.new('You cannot change this booking.', code: 'FORBIDDEN', status: 403) unless allowed
  end
end
