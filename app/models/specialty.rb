class Specialty < ApplicationRecord
  has_many :practitioners, dependent: :nullify

  before_validation :assign_slug

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :slug, presence: true, uniqueness: true

  scope :alphabetical, -> { order(Arel.sql("LOWER(name)")) }

  def in_use?
    practitioners.exists?
  end

  def usage_count
    practitioners.count
  end

  private

  def assign_slug
    return if name.blank?
    self.slug = name.parameterize
  end
end
