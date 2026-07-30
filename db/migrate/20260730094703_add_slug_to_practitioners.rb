class AddSlugToPractitioners < ActiveRecord::Migration[8.1]
  def up
    add_column :practitioners, :slug, :string

    Practitioner.reset_column_information
    Practitioner.find_each do |practitioner|
      next if practitioner.slug.present?

      base = [practitioner.full_name, practitioner.city]
               .compact_blank
               .map { |s| s.to_s.parameterize }
               .reject(&:blank?)
               .join("-")
               .presence || "practitioner"

      candidate = base
      n = 2
      while Practitioner.where.not(id: practitioner.id).exists?(slug: candidate)
        candidate = "#{base}-#{n}"
        n += 1
      end
      practitioner.update_column(:slug, candidate)
    end

    add_index :practitioners, :slug, unique: true
  end

  def down
    remove_index :practitioners, :slug
    remove_column :practitioners, :slug
  end
end
