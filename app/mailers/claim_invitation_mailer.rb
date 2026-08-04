class ClaimInvitationMailer < ApplicationMailer
  def invite
    @invitation  = params[:invitation]
    @practitioner = @invitation.practitioner
    @claim_url   = claim_url(token: @invitation.unique_token)
    @expires_on  = @invitation.expires_at.to_date

    mail to: @invitation.email_sent_to,
         subject: "Claim your Holistic Health profile"
  end
end
