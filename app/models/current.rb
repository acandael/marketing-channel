class Current < ActiveSupport::CurrentAttributes
  attribute :session

  def user
    session&.impersonated_user || session&.user
  end

  def true_user
    session&.user
  end

  def impersonating?
    session&.impersonating? || false
  end
end
