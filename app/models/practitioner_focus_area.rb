class PractitionerFocusArea < ApplicationRecord
  belongs_to :practitioner
  belongs_to :focus_area

  validates :practitioner_id, uniqueness: { scope: :focus_area_id }
end
