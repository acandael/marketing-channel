class PractitionerSpecialty < ApplicationRecord
  belongs_to :practitioner
  belongs_to :specialty

  validates :practitioner_id, uniqueness: { scope: :specialty_id }
end
