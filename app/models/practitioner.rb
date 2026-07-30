class Practitioner < ApplicationRecord
  SALUTATIONS = ["Herr", "Frau", "Dr.", "Prof. Dr.", "Prof."].freeze

  BUNDESLAENDER = [
    "Baden-Württemberg",
    "Bayern",
    "Berlin",
    "Brandenburg",
    "Bremen",
    "Hamburg",
    "Hessen",
    "Mecklenburg-Vorpommern",
    "Niedersachsen",
    "Nordrhein-Westfalen",
    "Rheinland-Pfalz",
    "Saarland",
    "Sachsen",
    "Sachsen-Anhalt",
    "Schleswig-Holstein",
    "Thüringen"
  ].freeze

  DAYS_OF_WEEK = %w[monday tuesday wednesday thursday friday saturday sunday].freeze

  PREMIUM_FIELDS = %i[
    profile_photo short_tagline long_bio treatments opening_hours
    languages_spoken qualifications years_in_practice gallery_images
  ].freeze

  belongs_to :user, optional: true
  has_many :practitioner_specialties, dependent: :destroy
  has_many :specialties, through: :practitioner_specialties
  has_many :claim_invitations, dependent: :destroy
  has_one  :latest_claim_invitation, -> { order(sent_at: :desc) }, class_name: "ClaimInvitation"
  has_many :treatments, dependent: :destroy

  has_rich_text :long_bio

  has_one_attached :profile_photo do |attachable|
    attachable.variant :square, resize_to_fill: [400, 400], format: :webp, saver: { quality: 85 }
    attachable.variant :thumb,  resize_to_fill: [96, 96],   format: :webp, saver: { quality: 85 }
  end

  has_many_attached :gallery_images do |attachable|
    attachable.variant :preview, resize_to_limit: [800, 800], format: :webp, saver: { quality: 82 }
    attachable.variant :thumb,   resize_to_fill: [200, 200], format: :webp, saver: { quality: 82 }
  end

  geocoded_by :full_address do |practitioner, results|
    if (result = results.first)
      practitioner.latitude  = result.latitude
      practitioner.longitude = result.longitude
    end
  end

  before_validation :geocode_if_address_changed
  before_validation :assign_slug

  validates :full_name, :city, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :salutation, inclusion: { in: SALUTATIONS, allow_blank: true }
  validates :bundesland, inclusion: { in: BUNDESLAENDER, allow_blank: true }
  validates :postal_code, format: { with: /\A\d{5}\z/, allow_blank: true, message: "must be a 5-digit German PLZ" }
  validates :public_email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :short_tagline, length: { maximum: 140, allow_blank: true }
  validates :years_in_practice, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true }
  validate :validate_profile_photo
  validate :validate_gallery_images

  scope :published,   -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :claimed,     -> { where.not(claimed_at: nil) }
  scope :unclaimed,   -> { where(claimed_at: nil) }
  scope :by_name,     ->(q) { where("full_name ILIKE ?", "%#{sanitize_sql_like(q)}%") if q.present? }
  scope :by_city,     ->(c) { where(city: c) if c.present? }
  scope :with_specialty, ->(id) { joins(:practitioner_specialties).where(practitioner_specialties: { specialty_id: id }) if id.present? }
  scope :by_location, ->(q) {
    next all if q.blank?
    query = q.to_s.strip
    if query.match?(/\A\d+\z/)
      where("postal_code LIKE ?", "#{query}%")
    else
      where("city ILIKE ?", "%#{sanitize_sql_like(query)}%")
    end
  }
  scope :by_query, ->(q) {
    next all if q.blank?
    query = "%#{sanitize_sql_like(q.to_s.strip)}%"
    matching_ids = unscoped
      .left_joins(:specialties)
      .where("practitioners.full_name ILIKE :q OR specialties.name ILIKE :q", q: query)
      .select("practitioners.id")
    where(id: matching_ids)
  }

  MAX_IMAGE_BYTES = 5.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_GALLERY_IMAGES = 10

  def to_param
    slug.presence || super
  end

  def languages_list
    (languages_spoken || "").split(/\r?\n/).map(&:strip).reject(&:blank?)
  end

  def qualifications_list
    (qualifications || "").split(/\r?\n/).map(&:strip).reject(&:blank?)
  end

  def opening_hours_for(day)
    entry = opening_hours[day.to_s]
    return nil unless entry.is_a?(Hash) && entry["open"].present? && entry["close"].present?
    entry
  end

  def has_any_opening_hours?
    DAYS_OF_WEEK.any? { |d| opening_hours_for(d) }
  end

  def opening_hours=(value)
    if value.is_a?(Hash)
      normalized = {}
      value.each do |day, entry|
        next unless DAYS_OF_WEEK.include?(day.to_s)
        if entry.is_a?(Hash)
          open  = entry["open"].to_s.strip
          close = entry["close"].to_s.strip
          closed_flag = entry["closed"].to_s == "1"
          if closed_flag || open.blank? || close.blank?
            normalized[day.to_s] = nil
          else
            normalized[day.to_s] = { "open" => open, "close" => close }
          end
        end
      end
      super(normalized)
    else
      super
    end
  end

  def profile_completeness
    filled = 0
    filled += 1 if profile_photo.attached?
    filled += 1 if short_tagline.present?
    filled += 1 if long_bio.body.present?
    filled += 1 if treatments.any?
    filled += 1 if has_any_opening_hours?
    filled += 1 if languages_list.any?
    filled += 1 if qualifications_list.any?
    filled += 1 if years_in_practice.present?
    filled += 1 if gallery_images.attached?
    ((filled.to_f / 9) * 100).round
  end

  def missing_premium_fields
    missing = []
    missing << "profile photo"    unless profile_photo.attached?
    missing << "short tagline"    if short_tagline.blank?
    missing << "long bio"         if long_bio.body.blank?
    missing << "treatments"       if treatments.empty?
    missing << "opening hours"    unless has_any_opening_hours?
    missing << "languages spoken" if languages_list.empty?
    missing << "qualifications"   if qualifications_list.empty?
    missing << "years in practice" if years_in_practice.blank?
    missing << "gallery images"   unless gallery_images.attached?
    missing
  end

  def status_labels
    labels = []
    labels << (published? ? "Published" : "Unpublished")
    labels << (claimed? ? "Claimed" : "Unclaimed")
    labels
  end

  def claimed?
    claimed_at.present?
  end

  def full_address
    [street_address, [postal_code, city].compact_blank.join(" "), "Germany"].compact_blank.join(", ")
  end

  def coordinates?
    latitude.present? && longitude.present?
  end

  private

  def assign_slug
    return if slug.present? && !full_name_changed? && !city_changed?
    return if full_name.blank?

    base_parts = [full_name, city].compact_blank.map { |s| s.to_s.parameterize }
    base = base_parts.reject(&:blank?).join("-").presence || "practitioner"

    candidate = base
    n = 2
    scope = self.class.where.not(id: id || 0)
    while scope.exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end

  def validate_profile_photo
    return unless profile_photo.attached?
    if profile_photo.blob.byte_size > MAX_IMAGE_BYTES
      errors.add(:profile_photo, "must be smaller than 5 MB")
    end
    unless ALLOWED_IMAGE_TYPES.include?(profile_photo.blob.content_type)
      errors.add(:profile_photo, "must be a JPEG, PNG, or WebP image")
    end
  end

  def validate_gallery_images
    return unless gallery_images.attached?
    if gallery_images.count > MAX_GALLERY_IMAGES
      errors.add(:gallery_images, "cannot have more than #{MAX_GALLERY_IMAGES} images")
    end
    gallery_images.each do |img|
      if img.blob.byte_size > MAX_IMAGE_BYTES
        errors.add(:gallery_images, "each image must be smaller than 5 MB")
        break
      end
      unless ALLOWED_IMAGE_TYPES.include?(img.blob.content_type)
        errors.add(:gallery_images, "each image must be a JPEG, PNG, or WebP")
        break
      end
    end
  end

  def geocode_if_address_changed
    return unless street_address_changed? || postal_code_changed? || city_changed?
    return if full_address.blank?
    # Skip re-geocoding if lat/lng were manually set alongside address change (i.e. changed together)
    return if latitude_changed? && longitude_changed?

    geocode
  rescue => e
    Rails.logger.warn "Geocoding failed for #{full_address}: #{e.class}: #{e.message}"
  end
end
