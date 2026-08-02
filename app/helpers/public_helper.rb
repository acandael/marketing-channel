module PublicHelper
  def avatar_initial(practitioner)
    source = practitioner.full_name.to_s.gsub(/^(Dr\.?|Prof\.?|Herr|Frau|Prof\. Dr\.?)\s+/i, "").strip
    (source.presence || practitioner.full_name.to_s).chars.first&.upcase || "?"
  end

  def page_description_for(practitioner)
    parts = [practitioner.specialty&.name, *practitioner.focus_areas.limit(2).pluck(:name)].compact_blank
    if parts.any?
      "#{practitioner.full_name}: #{parts.join(', ')} in #{practitioner.city}."
    else
      "#{practitioner.full_name} in #{practitioner.city}."
    end
  end

  def display_name(practitioner)
    [practitioner.salutation, practitioner.full_name].compact_blank.join(" ")
  end
end
