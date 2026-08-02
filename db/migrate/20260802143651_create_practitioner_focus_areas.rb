class CreatePractitionerFocusAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :practitioner_focus_areas do |t|
      t.references :practitioner, null: false, foreign_key: true
      t.references :focus_area, null: false, foreign_key: true

      t.timestamps
    end
    add_index :practitioner_focus_areas, [:practitioner_id, :focus_area_id],
              unique: true, name: "index_practitioner_focus_areas_uniqueness"
  end
end
