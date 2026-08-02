class CreateFocusAreas < ActiveRecord::Migration[8.1]
  def change
    create_table :focus_areas do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end
    add_index :focus_areas, :name, unique: true
    add_index :focus_areas, :slug, unique: true
  end
end
