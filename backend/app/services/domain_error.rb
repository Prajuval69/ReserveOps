# frozen_string_literal: true

class DomainError < StandardError
  attr_reader :code, :status, :details

  def initialize(message, code: 'VALIDATION_ERROR', status: 422, details: {})
    super(message)
    @code = code
    @status = status
    @details = details
  end
end
