module PractitionerHelper
  DAY_LABELS = {
    "monday"    => "Mon",
    "tuesday"   => "Tue",
    "wednesday" => "Wed",
    "thursday"  => "Thu",
    "friday"    => "Fri",
    "saturday"  => "Sat",
    "sunday"    => "Sun"
  }.freeze

  def day_label(day)
    DAY_LABELS[day.to_s]
  end

  def format_opening_hours(entry)
    return "Closed" if entry.nil?
    "#{entry["open"]} – #{entry["close"]}"
  end
end
