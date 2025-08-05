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

ActiveRecord::Schema[8.0].define(version: 2025_08_04_161625) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "collections", force: :cascade do |t|
    t.string "druid", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["druid"], name: "index_collections_on_druid", unique: true
  end

  create_table "collections_purls", id: false, force: :cascade do |t|
    t.integer "purl_id"
    t.integer "collection_id"
    t.index ["collection_id"], name: "index_collections_purls_on_collection_id"
    t.index ["purl_id"], name: "index_collections_purls_on_purl_id"
  end

  create_table "constituent_memberships", force: :cascade do |t|
    t.integer "parent_id", null: false
    t.integer "child_id", null: false
    t.integer "sort_order", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_constituent_memberships_on_child_id"
    t.index ["parent_id", "child_id"], name: "index_constituent_memberships_on_parent_id_and_child_id", unique: true
    t.index ["parent_id"], name: "index_constituent_memberships_on_parent_id"
  end

  create_table "listener_logs", force: :cascade do |t|
    t.integer "process_id", null: false
    t.datetime "started_at", precision: nil, null: false
    t.datetime "active_at", precision: nil
    t.datetime "ended_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["process_id"], name: "index_listener_logs_on_process_id"
    t.index ["started_at"], name: "index_listener_logs_on_started_at"
  end

  create_table "public_jsons", force: :cascade do |t|
    t.integer "purl_id"
    t.binary "data", limit: 16777216
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "data_type"
    t.index ["purl_id"], name: "index_public_jsons_on_purl_id"
  end

  create_table "purls", force: :cascade do |t|
    t.string "druid", null: false
    t.string "object_type"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.datetime "published_at", precision: nil
    t.text "title"
    t.string "catkey"
    t.integer "version"
    t.string "content_type"
    t.index ["content_type"], name: "index_purls_on_content_type"
    t.index ["deleted_at"], name: "index_purls_on_deleted_at"
    t.index ["druid"], name: "index_purls_on_druid", unique: true
    t.index ["object_type"], name: "index_purls_on_object_type"
    t.index ["published_at", "deleted_at"], name: "index_purls_on_published_at_and_deleted_at"
    t.index ["published_at"], name: "index_purls_on_published_at"
    t.index ["updated_at"], name: "index_purls_on_updated_at"
  end

  create_table "release_tags", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "release_type", null: false
    t.integer "purl_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name", "purl_id"], name: "index_release_tags_on_name_and_purl_id", unique: true
    t.index ["purl_id"], name: "index_release_tags_on_purl_id"
    t.index ["release_type"], name: "index_release_tags_on_release_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "constituent_memberships", "purls", column: "child_id"
  add_foreign_key "constituent_memberships", "purls", column: "parent_id"
end
