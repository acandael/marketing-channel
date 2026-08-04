class Public::RegistrationsController < Public::BaseController
  def new
    @form = registration_defaults
    @specialties = Specialty.alphabetical
  end

  def create
    @form = registration_defaults.merge(sanitized_params)
    @specialties = Specialty.alphabetical

    email = @form[:email].to_s.strip.downcase
    full_name = @form[:full_name].to_s.strip
    city = @form[:city].to_s.strip

    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = "Please provide a valid email address."
      return render :new, status: :unprocessable_content
    end
    if full_name.blank? || city.blank?
      flash.now[:alert] = "Full name and city are required."
      return render :new, status: :unprocessable_content
    end

    if User.exists?(["LOWER(email_address) = ?", email])
      redirect_to new_session_path,
                  alert: "An account with that email already exists. Please sign in."
      return
    end

    match = Practitioner.find_potential_match(full_name, city)

    if match&.claimed?
      redirect_to new_session_path,
                  alert: "A profile for #{match.full_name} in #{match.city} is already listed and claimed. Please sign in."
      return
    end

    practitioner = match || build_new_practitioner(full_name: full_name, city: city)

    unless practitioner.persisted?
      unless practitioner.save
        flash.now[:alert] = practitioner.errors.full_messages.to_sentence
        return render :new, status: :unprocessable_content
      end
    end

    ClaimInvitation.invalidate_pending_for(practitioner)
    invitation = practitioner.claim_invitations.create!(email_sent_to: email)
    ClaimInvitationMailer.with(invitation: invitation).invite.deliver_later

    @sent_to = email
    @matched_existing = match.present?
    flash.now[:notice] = "Verification email sent to #{email}. Check your inbox to finish setting up your profile."
    render :sent
  end

  private

  def registration_defaults
    { email: "", full_name: "", street_address: "", city: "", postal_code: "",
      phone: "", public_email: "", short_tagline: "", specialty_id: nil }
  end

  def sanitized_params
    params.fetch(:registration, {}).permit(
      :email, :full_name, :street_address, :city, :postal_code, :phone,
      :public_email, :short_tagline, :specialty_id
    ).to_h.symbolize_keys
  end

  def build_new_practitioner(full_name:, city:)
    Practitioner.new(
      full_name: full_name,
      city: city,
      street_address: @form[:street_address].presence,
      postal_code: @form[:postal_code].presence,
      phone: @form[:phone].presence,
      public_email: @form[:public_email].presence,
      short_tagline: @form[:short_tagline].presence,
      specialty_id: @form[:specialty_id].presence,
      published: false
    )
  end
end
