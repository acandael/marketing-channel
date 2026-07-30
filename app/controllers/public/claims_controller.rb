class Public::ClaimsController < Public::BaseController
  before_action :set_invitation

  def show
    render_state
  end

  def create
    if @invitation.nil? || !@invitation.pending?
      return render_state
    end

    email = params[:email].to_s.strip.downcase
    password = params[:password].to_s

    @submitted_email = email
    @error = nil

    if email.blank? || !email.match?(URI::MailTo::EMAIL_REGEXP)
      @error = "Please provide a valid email address."
      return render :show, status: :unprocessable_content
    end
    if password.length < 8
      @error = "Password must be at least 8 characters."
      return render :show, status: :unprocessable_content
    end

    user = nil
    ActiveRecord::Base.transaction do
      user = User.new(email_address: email, password: password, role: :practitioner)
      user.save!

      practitioner = @invitation.practitioner
      practitioner.update!(user: user, claimed_at: Time.current)
      @invitation.update!(claimed_at: Time.current)
      ClaimInvitation.invalidate_pending_for(practitioner)
    end

    start_new_session_for user
    redirect_to practitioner_root_path,
                notice: "Welcome — your profile is now yours."
  rescue ActiveRecord::RecordInvalid => e
    @error = e.record.errors.full_messages.to_sentence.presence || "Something went wrong. Please try again."
    render :show, status: :unprocessable_content
  end

  private

  def set_invitation
    @invitation = ClaimInvitation.find_by(unique_token: params[:token])
  end

  def render_state
    if @invitation.nil?
      render :error, locals: { title: "Invitation not found", body: "This invitation link isn't valid. Please contact the admin who sent it." }, status: :not_found
    elsif @invitation.claimed?
      render :error, locals: { title: "Profile already claimed", body: "This profile was already claimed. Sign in with your existing credentials to manage it.", show_sign_in: true }, status: :gone
    elsif @invitation.expired?
      render :error, locals: { title: "Invitation expired", body: "This invitation expired on #{@invitation.expires_at.to_date.strftime("%-d %B %Y")}. Ask the admin who invited you to send a new one." }, status: :gone
    else
      render :show
    end
  end
end
