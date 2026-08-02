class MigrateSpecialtiesToPractitionerSpecialtyId < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE practitioners p
      SET specialty_id = sub.specialty_id
      FROM (
        SELECT DISTINCT ON (ps.practitioner_id)
               ps.practitioner_id, ps.specialty_id
        FROM practitioner_specialties ps
        JOIN specialties s ON s.id = ps.specialty_id
        ORDER BY ps.practitioner_id, LOWER(s.name)
      ) sub
      WHERE p.id = sub.practitioner_id
    SQL
  end

  def down
    execute "UPDATE practitioners SET specialty_id = NULL"
  end
end
