# frozen_string_literal: true

class TimeInput
  def self.parse(value)
    text = value.to_s
    raise ArgumentError unless text.match?(/T.*(?:Z|[+-]\d{2}:\d{2})\z/)

    Time.iso8601(text).utc
  rescue ArgumentError, TypeError
    raise DomainError, 'Use an ISO8601 timestamp with an explicit timezone.'
  end
end
