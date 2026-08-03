module AdminHelper
  def status_badges_for(practitioner)
    safe_join([
      tag.span(practitioner.published? ? "Published" : "Unpublished",
        class: "badge #{practitioner.published? ? "badge--published" : "badge--unpublished"}"),
      tag.span(practitioner.claimed? ? "Claimed" : "Unclaimed",
        class: "badge #{practitioner.claimed? ? "badge--claimed" : "badge--unclaimed"}")
    ], " ")
  end

  def sort_link_to(label, column, params)
    current_sort = params[:sort]
    current_direction = params[:direction]
    is_active = current_sort == column
    next_direction = is_active && current_direction == "asc" ? "desc" : "asc"
    indicator = if is_active
      current_direction == "asc" ? "↑" : "↓"
    else
      "↕"
    end

    link_to(
      safe_join([label, tag.span(indicator, class: "table__sort-indicator")], " "),
      params.to_unsafe_h.merge(sort: column, direction: next_direction, page: 1),
      class: "table__sort-link"
    )
  end

  def invitation_status_chip(practitioner)
    invitation = practitioner.latest_claim_invitation
    if invitation.nil?
      tag.span("Never invited", class: "badge badge--muted")
    else
      case invitation.status
      when :claimed
        tag.span("Claimed #{time_ago_in_words(invitation.claimed_at)} ago",
          class: "badge badge--published", title: "Claimed on #{invitation.claimed_at.to_date}")
      when :expired
        tag.span("Invite expired", class: "badge badge--unpublished",
          title: "Sent #{time_ago_in_words(invitation.sent_at)} ago, expired #{invitation.expires_at.to_date}")
      when :pending
        tag.span("Invited #{time_ago_in_words(invitation.sent_at)} ago",
          class: "badge badge--unclaimed", title: "Sent to #{invitation.email_sent_to}, expires #{invitation.expires_at.to_date}")
      end
    end
  end
end
