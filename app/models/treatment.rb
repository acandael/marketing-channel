class Treatment < ApplicationRecord
  belongs_to :practitioner

  before_validation :assign_position, on: :create

  validates :title, presence: true, length: { maximum: 120 }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 480, allow_nil: true }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :position, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :id) }

  def price_euros
    return nil if price_cents.nil?
    price_cents / 100.0
  end

  def price_euros=(value)
    self.price_cents = if value.blank?
      nil
    else
      normalized = value.to_s.tr(",", ".").strip
      (normalized.to_f * 100).round
    end
  end

  def formatted_price
    return nil if price_cents.nil?
    format("%.2f €", price_euros).sub(".", ",")
  end

  def duration_display
    return nil if duration_minutes.nil?
    "#{duration_minutes} min"
  end

  private

  # `position` intentionally has no default in the DB, so `nil` reliably means
  # "not explicitly set" and the callback assigns the next available slot.
  def assign_position
    return unless position.nil?
    max = practitioner&.treatments&.where.not(id: id)&.maximum(:position) || -1
    self.position = max + 1
  end
end
