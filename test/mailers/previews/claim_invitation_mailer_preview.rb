class ClaimInvitationMailerPreview < ActionMailer::Preview
  def invite
    invitation = ClaimInvitation.pending.first || ClaimInvitation.first

    if invitation.nil?
      practitioner = Practitioner.first || Practitioner.new(full_name: "Sample Practitioner", city: "Berlin")
      invitation = ClaimInvitation.new(
        practitioner: practitioner,
        unique_token: "sample-preview-token-9x8y7z",
        email_sent_to: "practitioner@example.com",
        sent_at: Time.current,
        expires_at: 30.days.from_now
      )
    end

    ClaimInvitationMailer.with(invitation: invitation).invite
  end
end
