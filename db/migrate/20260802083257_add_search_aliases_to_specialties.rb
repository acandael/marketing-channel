class AddSearchAliasesToSpecialties < ActiveRecord::Migration[8.1]
  def change
    add_column :specialties, :search_aliases, :text
  end
end
