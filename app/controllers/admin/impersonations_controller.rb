class Admin::ImpersonationsController < ApplicationController
  include AdminAuthorization

  def create
    practitioner = Practitioner.find_by!(slug: params[:id])

    if practitioner.user_id.blank?
      redirect_to edit_admin_practitioner_path(practitioner),
                  alert: "This practitioner hasn't claimed their profile, so there's no account to impersonate."
      return
    end

    if practitioner.user_id == Current.true_user.id
      redirect_to edit_admin_practitioner_path(practitioner),
                  alert: "You can't impersonate your own account."
      return
    end

    Current.session.update!(impersonated_user_id: practitioner.user_id)
    Rails.logger.tagged("Impersonation") do
      Rails.logger.info(
        "admin_user_id=#{Current.true_user.id} started impersonation " \
        "target_user_id=#{practitioner.user_id} practitioner_id=#{practitioner.id}"
      )
    end

    redirect_to practitioner_root_path,
                notice: "Now impersonating #{practitioner.full_name}. Use the banner to return to admin."
  end

  def destroy
    if Current.impersonating?
      practitioner = Current.session.impersonated_user&.practitioner
      target_user_id = Current.session.impersonated_user_id

      Current.session.update!(impersonated_user_id: nil)
      Rails.logger.tagged("Impersonation") do
        Rails.logger.info(
          "admin_user_id=#{Current.true_user.id} stopped impersonation " \
          "target_user_id=#{target_user_id}"
        )
      end

      redirect_target = practitioner ? edit_admin_practitioner_path(practitioner) : admin_root_path
      redirect_to redirect_target, notice: "Stopped impersonating."
    else
      redirect_to admin_root_path
    end
  end
end
