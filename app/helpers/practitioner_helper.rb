module PractitionerHelper
  DAY_LABELS = {
    "monday"    => "Mo",
    "tuesday"   => "Di",
    "wednesday" => "Mi",
    "thursday"  => "Do",
    "friday"    => "Fr",
    "saturday"  => "Sa",
    "sunday"    => "So"
  }.freeze

  DAY_FULL_LABELS = {
    "monday"    => "Montag",
    "tuesday"   => "Dienstag",
    "wednesday" => "Mittwoch",
    "thursday"  => "Donnerstag",
    "friday"    => "Freitag",
    "saturday"  => "Samstag",
    "sunday"    => "Sonntag"
  }.freeze

  def day_label(day)
    DAY_LABELS[day.to_s]
  end

  def day_full_label(day)
    DAY_FULL_LABELS[day.to_s]
  end

  def format_opening_hours(entry)
    return "Geschlossen" if entry.nil?
    "#{entry["open"]} – #{entry["close"]}"
  end
end
