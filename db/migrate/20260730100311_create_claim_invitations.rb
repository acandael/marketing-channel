class CreateClaimInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :claim_invitations do |t|
      t.references :practitioner, null: false, foreign_key: true
      t.string :unique_token, null: false
      t.string :email_sent_to, null: false
      t.datetime :sent_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :claimed_at

      t.timestamps
    end

    add_index :claim_invitations, :unique_token, unique: true
    add_index :claim_invitations, [:practitioner_id, :sent_at]
  end
end
