class AddGalleryOrderToPractitioners < ActiveRecord::Migration[8.1]
  def change
    add_column :practitioners, :gallery_order, :jsonb, default: [], null: false
  end
end
