class Admin::BaseController < ApplicationController
  include AdminAuthorization
  include Pagy::Backend

  layout "admin"

  helper_method :current_admin
  helper Pagy::Frontend

  private

  def current_admin
    Current.user
  end
end
