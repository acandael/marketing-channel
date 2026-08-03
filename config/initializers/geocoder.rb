contact_url = ENV.fetch("APP_HOST", "example.com")
contact_email = ENV["GEOCODER_CONTACT_EMAIL"]
contact = contact_email.present? ? "#{contact_email}; +https://#{contact_url}" : "+https://#{contact_url}"

Geocoder.configure(
  lookup: :nominatim,
  timeout: 5,
  units: :km,
  language: "de",
  http_headers: {
    "User-Agent" => "Mozilla/5.0 (compatible; MarketingChannelDirectory/0.1; #{contact})"
  }
)
