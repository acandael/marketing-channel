class Practitioner::BaseController < ApplicationController
  include PractitionerAuthorization

  layout "practitioner"

  before_action :set_practitioner

  helper_method :current_practitioner

  private

  def set_practitioner
    @practitioner = Current.user.practitioner
    return if @practitioner

    flash[:alert] = "Your account isn't linked to a practitioner profile. Please contact an admin."
    redirect_to root_path
  end

  def current_practitioner
    @practitioner
  end
end
