module PractitionerAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_practitioner
  end

  private

  def require_practitioner
    return if Current.user&.practitioner?

    if Current.user&.admin?
      redirect_to admin_root_path,
                  alert: "This area is for practitioners. Admins have their own console."
    else
      redirect_to new_session_path,
                  alert: "Please sign in to continue."
    end
  end
end
