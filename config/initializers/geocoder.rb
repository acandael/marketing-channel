Geocoder.configure(
  lookup: :nominatim,
  timeout: 5,
  units: :km,
  language: "de",
  http_headers: {
    "User-Agent" => "Mozilla/5.0 (compatible; MarketingChannelDirectory/0.1; +https://example.com)"
  }
)
