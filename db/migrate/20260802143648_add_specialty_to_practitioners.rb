class AddSpecialtyToPractitioners < ActiveRecord::Migration[8.1]
  def change
    add_reference :practitioners, :specialty, null: true, foreign_key: true
  end
end
