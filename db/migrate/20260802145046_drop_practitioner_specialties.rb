class DropPractitionerSpecialties < ActiveRecord::Migration[8.1]
  def up
    drop_table :practitioner_specialties
  end

  def down
    create_table :practitioner_specialties do |t|
      t.references :practitioner, null: false, foreign_key: true
      t.references :specialty, null: false, foreign_key: true
      t.timestamps
    end
    add_index :practitioner_specialties, [:practitioner_id, :specialty_id],
              unique: true, name: "index_practitioner_specialties_uniqueness"
  end
end
