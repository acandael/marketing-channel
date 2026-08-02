class RemoveLanguagesSpokenFromPractitioners < ActiveRecord::Migration[8.1]
  def change
    remove_column :practitioners, :languages_spoken, :text
  end
end
