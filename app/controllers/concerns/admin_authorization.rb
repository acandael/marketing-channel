module AdminAuthorization
  extend ActiveSupport::Concern

  included do
    before_action :require_admin
  end

  private

  def require_admin
    unless Current.user&.admin?
      flash[:alert] = "Admins only."
      redirect_to root_path
    end
  end
end
