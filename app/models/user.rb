class User < ApplicationRecord
  EMAIL_CHANGE_LIFETIME = 24.hours

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_one :practitioner, dependent: :nullify

  enum :role, { admin: "admin", practitioner: "practitioner" }, default: "practitioner"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :pending_email_address, with: ->(e) { e&.strip&.downcase }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(deleted_at: nil) }

  def self.authenticate_by(attrs)
    active.find_by(email_address: attrs[:email_address])&.authenticate(attrs[:password]) || nil
  end

  def deleted?
    deleted_at.present?
  end

  def start_email_change!(new_email)
    self.pending_email_address = new_email
    self.email_change_token    = generate_email_change_token
    self.email_change_sent_at  = Time.current
    save!
  end

  def confirm_email_change!
    return false if pending_email_address.blank?
    return false if email_change_sent_at.nil?
    return false if email_change_sent_at + EMAIL_CHANGE_LIFETIME <= Time.current

    self.email_address         = pending_email_address
    self.pending_email_address = nil
    self.email_change_token    = nil
    self.email_change_sent_at  = nil
    save!
  end

  def email_change_expired?
    email_change_sent_at.present? && email_change_sent_at + EMAIL_CHANGE_LIFETIME <= Time.current
  end

  private

  def generate_email_change_token
    loop do
      candidate = SecureRandom.urlsafe_base64(32)
      break candidate unless self.class.where.not(id: id).exists?(email_change_token: candidate)
    end
  end
end
