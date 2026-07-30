class CreatePractitioners < ActiveRecord::Migration[8.1]
  def change
    create_table :practitioners do |t|
      t.string :salutation
      t.string :full_name, null: false
      t.string :street_address
      t.string :postal_code
      t.string :city, null: false
      t.string :bundesland
      t.string :phone
      t.string :public_email
      t.string :website_url
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.boolean :published, null: false, default: false
      t.datetime :claimed_at
      t.references :user, foreign_key: true, index: { unique: true }

      t.timestamps
    end

    add_index :practitioners, :city
    add_index :practitioners, :postal_code
    add_index :practitioners, :published
    add_index :practitioners, [:latitude, :longitude]
  end
end
