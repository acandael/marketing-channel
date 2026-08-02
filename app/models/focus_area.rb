class FocusArea < ApplicationRecord
  has_many :practitioner_focus_areas, dependent: :destroy
  has_many :practitioners, through: :practitioner_focus_areas

  before_validation :assign_slug
  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  scope :alphabetical, -> { order(Arel.sql("LOWER(name)")) }

  def self.find_or_create_by_name(raw_name)
    normalized = raw_name.to_s.strip.squeeze(" ")
    return nil if normalized.blank?
    existing = where("LOWER(name) = ?", normalized.downcase).first
    return existing if existing
    create(name: normalized)
  end

  def in_use?
    practitioner_focus_areas.exists?
  end

  def usage_count
    practitioners.count
  end

  private

  def normalize_name
    self.name = name.to_s.strip.squeeze(" ") if name.present?
  end

  def assign_slug
    return if name.blank?
    self.slug = name.parameterize
  end
end
