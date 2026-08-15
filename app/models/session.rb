class Session < ApplicationRecord
  belongs_to :user
  belongs_to :impersonated_user, class_name: "User", optional: true

  def impersonating?
    impersonated_user_id.present?
  end
end
