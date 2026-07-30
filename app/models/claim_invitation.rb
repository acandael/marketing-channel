class ClaimInvitation < ApplicationRecord
  TOKEN_BYTES = 32
  LIFETIME = 30.days

  belongs_to :practitioner

  before_validation :generate_token, on: :create
  before_validation :set_default_expiration, on: :create
  before_validation :set_default_sent_at, on: :create

  validates :unique_token, presence: true, uniqueness: true
  validates :email_sent_to, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :expires_at, :sent_at, presence: true

  scope :pending, -> { where(claimed_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where(claimed_at: nil).where("expires_at <= ?", Time.current) }
  scope :claimed, -> { where.not(claimed_at: nil) }

  def self.invalidate_pending_for(practitioner)
    pending.where(practitioner_id: practitioner.id).update_all(expires_at: 1.second.ago)
  end

  def status
    return :claimed if claimed_at.present?
    return :expired if expires_at <= Time.current
    :pending
  end

  def claimed?
    claimed_at.present?
  end

  def expired?
    !claimed? && expires_at <= Time.current
  end

  def pending?
    !claimed? && expires_at > Time.current
  end

  def to_param
    unique_token
  end

  private

  def generate_token
    return if unique_token.present?
    loop do
      candidate = SecureRandom.urlsafe_base64(TOKEN_BYTES)
      unless self.class.exists?(unique_token: candidate)
        self.unique_token = candidate
        break
      end
    end
  end

  def set_default_expiration
    self.expires_at ||= LIFETIME.from_now
  end

  def set_default_sent_at
    self.sent_at ||= Time.current
  end
end
