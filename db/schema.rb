# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_30_133032) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "claim_invitations", force: :cascade do |t|
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.string "email_sent_to", null: false
    t.datetime "expires_at", null: false
    t.bigint "practitioner_id", null: false
    t.datetime "sent_at", null: false
    t.string "unique_token", null: false
    t.datetime "updated_at", null: false
    t.index ["practitioner_id", "sent_at"], name: "index_claim_invitations_on_practitioner_id_and_sent_at"
    t.index ["practitioner_id"], name: "index_claim_invitations_on_practitioner_id"
    t.index ["unique_token"], name: "index_claim_invitations_on_unique_token", unique: true
  end

  create_table "practitioner_specialties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "practitioner_id", null: false
    t.bigint "specialty_id", null: false
    t.datetime "updated_at", null: false
    t.index ["practitioner_id", "specialty_id"], name: "index_practitioner_specialties_uniqueness", unique: true
    t.index ["practitioner_id"], name: "index_practitioner_specialties_on_practitioner_id"
    t.index ["specialty_id"], name: "index_practitioner_specialties_on_specialty_id"
  end

  create_table "practitioners", force: :cascade do |t|
    t.string "bundesland"
    t.string "city", null: false
    t.datetime "claimed_at"
    t.datetime "created_at", null: false
    t.string "full_name", null: false
    t.text "languages_spoken"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.jsonb "opening_hours", default: {}, null: false
    t.string "phone"
    t.string "postal_code"
    t.string "public_email"
    t.boolean "published", default: false, null: false
    t.text "qualifications"
    t.string "salutation"
    t.string "short_tagline"
    t.string "slug"
    t.string "street_address"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.string "website_url"
    t.integer "years_in_practice"
    t.index ["city"], name: "index_practitioners_on_city"
    t.index ["latitude", "longitude"], name: "index_practitioners_on_latitude_and_longitude"
    t.index ["postal_code"], name: "index_practitioners_on_postal_code"
    t.index ["published"], name: "index_practitioners_on_published"
    t.index ["slug"], name: "index_practitioners_on_slug", unique: true
    t.index ["user_id"], name: "index_practitioners_on_user_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "specialties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_specialties_on_name", unique: true
    t.index ["slug"], name: "index_specialties_on_slug", unique: true
  end

  create_table "treatments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes"
    t.integer "position", null: false
    t.bigint "practitioner_id", null: false
    t.integer "price_cents"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["practitioner_id", "position"], name: "index_treatments_on_practitioner_id_and_position"
    t.index ["practitioner_id"], name: "index_treatments_on_practitioner_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email_address", null: false
    t.datetime "email_change_sent_at"
    t.string "email_change_token"
    t.string "password_digest", null: false
    t.string "pending_email_address"
    t.string "role", default: "practitioner", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["email_change_token"], name: "index_users_on_email_change_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "claim_invitations", "practitioners"
  add_foreign_key "practitioner_specialties", "practitioners"
  add_foreign_key "practitioner_specialties", "specialties"
  add_foreign_key "practitioners", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "treatments", "practitioners"
end
