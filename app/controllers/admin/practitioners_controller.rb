class Admin::PractitionersController < Admin::BaseController
  SORT_COLUMNS = { "name" => "full_name", "city" => "city", "updated_at" => "updated_at" }.freeze
  before_action :set_practitioner, only: [:show, :edit, :update, :destroy]

  def index
    @filters = filter_params
    scope = Practitioner.includes(:specialty, :latest_claim_invitation)
                        .by_name(@filters[:q])
                        .by_city(@filters[:city])
                        .with_specialty(@filters[:specialty_id])

    scope = case @filters[:status]
            when "published"   then scope.published
            when "unpublished" then scope.unpublished
            when "claimed"     then scope.claimed
            when "unclaimed"   then scope.unclaimed
            else scope
            end

    sort_column = SORT_COLUMNS.fetch(@filters[:sort], "updated_at")
    sort_dir    = @filters[:direction] == "asc" ? "asc" : "desc"
    scope = scope.order(Arel.sql("#{sort_column} #{sort_dir}"))

    @cities = Practitioner.where.not(city: [nil, ""]).distinct.order(:city).pluck(:city)
    @specialties = Specialty.alphabetical

    @pagy, @practitioners = pagy(scope)
  end

  def show
    redirect_to edit_admin_practitioner_path(@practitioner)
  end

  def new
    @practitioner = Practitioner.new
  end

  def create
    @practitioner = Practitioner.new(practitioner_params)
    if @practitioner.save
      redirect_to edit_admin_practitioner_path(@practitioner),
                  notice: "Practitioner created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @practitioner.update(practitioner_params)
      redirect_to edit_admin_practitioner_path(@practitioner), notice: "Changes saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @practitioner.destroy
    redirect_to admin_practitioners_path, notice: "Practitioner deleted."
  end

  def bulk_publish
    updated = Practitioner.where(id: bulk_ids).update_all(published: true, updated_at: Time.current)
    redirect_to admin_practitioners_path, notice: "Published #{pluralize(updated, "practitioner")}."
  end

  def bulk_unpublish
    updated = Practitioner.where(id: bulk_ids).update_all(published: false, updated_at: Time.current)
    redirect_to admin_practitioners_path, notice: "Unpublished #{pluralize(updated, "practitioner")}."
  end

  def bulk_destroy
    deleted = Practitioner.where(id: bulk_ids).destroy_all.size
    redirect_to admin_practitioners_path, notice: "Deleted #{pluralize(deleted, "practitioner")}."
  end

  def send_claim_invitation
    practitioner = Practitioner.find_by!(slug: params[:id])

    if practitioner.claimed?
      redirect_to edit_admin_practitioner_path(practitioner),
                  alert: "This profile has already been claimed."
      return
    end

    email = params[:email].to_s.strip
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      redirect_to edit_admin_practitioner_path(practitioner),
                  alert: "Please provide a valid email address."
      return
    end

    ClaimInvitation.invalidate_pending_for(practitioner)

    invitation = practitioner.claim_invitations.create!(
      email_sent_to: email
    )

    ClaimInvitationMailer.with(invitation: invitation).invite.deliver_later

    redirect_to edit_admin_practitioner_path(practitioner),
                notice: "Invitation sent to #{email}. It expires on #{invitation.expires_at.to_date.strftime("%-d %B %Y")}."
  end

  private

  def set_practitioner
    @practitioner = Practitioner.find_by!(slug: params[:id])
  end

  def filter_params
    params.permit(:q, :city, :specialty_id, :status, :sort, :direction).to_h.symbolize_keys
  end

  def bulk_ids
    Array(params[:practitioner_ids]).map(&:to_i).reject(&:zero?)
  end

  def practitioner_params
    params.expect(practitioner: [
      :salutation, :full_name, :street_address, :postal_code, :city, :bundesland,
      :phone, :public_email, :website_url, :latitude, :longitude, :published,
      :specialty_id
    ])
  end
end
