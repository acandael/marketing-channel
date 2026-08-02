class RemoveYearsInPracticeFromPractitioners < ActiveRecord::Migration[8.1]
  def change
    remove_column :practitioners, :years_in_practice, :integer
  end
end
