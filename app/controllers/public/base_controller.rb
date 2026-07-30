class Public::BaseController < ApplicationController
  include Pagy::Backend

  allow_unauthenticated_access
  before_action :resume_session_for_layout

  layout "public"

  helper Pagy::Frontend

  private

  # Public pages don't require auth, but the layout wants to know whether
  # someone is signed in (to render the right nav). This resumes the session
  # if there's a cookie for one, but doesn't redirect if there isn't.
  def resume_session_for_layout
    resume_session
  end
end
