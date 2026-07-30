class AddPremiumFieldsToPractitioners < ActiveRecord::Migration[8.1]
  def change
    add_column :practitioners, :short_tagline, :string
    add_column :practitioners, :services_offered, :text
    add_column :practitioners, :languages_spoken, :text
    add_column :practitioners, :qualifications, :text
    add_column :practitioners, :years_in_practice, :integer
    add_column :practitioners, :opening_hours, :jsonb, default: {}, null: false
  end
end
