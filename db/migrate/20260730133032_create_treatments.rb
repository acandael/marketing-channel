class CreateTreatments < ActiveRecord::Migration[8.1]
  def up
    create_table :treatments do |t|
      t.references :practitioner, null: false, foreign_key: true
      t.string  :title, null: false
      t.text    :description
      t.integer :duration_minutes
      t.integer :price_cents
      t.integer :position, null: false

      t.timestamps
    end
    add_index :treatments, [:practitioner_id, :position]

    Practitioner.reset_column_information
    Practitioner.where.not(services_offered: [nil, ""]).find_each do |practitioner|
      lines = practitioner.services_offered.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
      lines.each_with_index do |line, idx|
        Treatment.create!(practitioner_id: practitioner.id, title: line, position: idx)
      end
    end

    remove_column :practitioners, :services_offered
  end

  def down
    add_column :practitioners, :services_offered, :text

    Practitioner.reset_column_information
    Treatment.group_by(&:practitioner_id).each do |pid, treatments|
      practitioner = Practitioner.find(pid)
      practitioner.update_column(:services_offered, treatments.sort_by(&:position).map(&:title).join("\n"))
    end

    drop_table :treatments
  end
end
