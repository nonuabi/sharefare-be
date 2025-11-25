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

ActiveRecord::Schema[8.0].define(version: 2025_11_25_105448) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "expenses", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.float "paid_amount"
    t.boolean "is_settled", default: false
    t.bigint "payer_id", null: false
    t.bigint "creator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description", default: "", null: false
    t.text "notes"
    t.index ["creator_id"], name: "index_expenses_on_creator_id"
    t.index ["group_id"], name: "index_expenses_on_group_id"
    t.index ["payer_id"], name: "index_expenses_on_payer_id"
  end

  create_table "group_invites", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "inviter_id", null: false
    t.string "token", null: false
    t.datetime "expires_at"
    t.boolean "used", default: false, null: false
    t.datetime "used_at"
    t.bigint "used_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_group_invites_on_group_id"
    t.index ["inviter_id"], name: "index_group_invites_on_inviter_id"
    t.index ["token"], name: "index_group_invites_on_token", unique: true
    t.index ["used_by_id"], name: "index_group_invites_on_used_by_id"
  end

  create_table "group_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_group_members_on_group_id"
    t.index ["user_id"], name: "index_group_members_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.bigint "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "avatar_svg"
    t.index ["owner_id"], name: "index_groups_on_owner_id"
  end

  create_table "settlements", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "payer_id", null: false
    t.bigint "payee_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.bigint "settled_by_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "payer_id", "payee_id"], name: "index_settlements_on_group_id_and_payer_id_and_payee_id"
    t.index ["group_id"], name: "index_settlements_on_group_id"
    t.index ["payee_id"], name: "index_settlements_on_payee_id"
    t.index ["payer_id"], name: "index_settlements_on_payer_id"
    t.index ["settled_by_id"], name: "index_settlements_on_settled_by_id"
  end

  create_table "split_expenses", force: :cascade do |t|
    t.float "paid_amount", default: 0.0
    t.float "due_amount", default: 0.0
    t.boolean "is_settled", default: false
    t.bigint "expense_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_split_expenses_on_expense_id"
    t.index ["user_id"], name: "index_split_expenses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "jti"
    t.string "name"
    t.text "avatar_svg"
    t.string "phone_number"
    t.boolean "email_verified", default: false, null: false
    t.string "email_verification_code"
    t.datetime "email_verification_code_sent_at"
    t.index ["email"], name: "index_users_on_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["jti"], name: "index_users_on_jti"
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true, where: "(phone_number IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "expenses", "groups"
  add_foreign_key "expenses", "users", column: "creator_id"
  add_foreign_key "expenses", "users", column: "payer_id"
  add_foreign_key "group_invites", "groups"
  add_foreign_key "group_invites", "users", column: "inviter_id"
  add_foreign_key "group_invites", "users", column: "used_by_id"
  add_foreign_key "group_members", "groups"
  add_foreign_key "group_members", "users"
  add_foreign_key "groups", "users", column: "owner_id"
  add_foreign_key "settlements", "groups"
  add_foreign_key "settlements", "users", column: "payee_id"
  add_foreign_key "settlements", "users", column: "payer_id"
  add_foreign_key "settlements", "users", column: "settled_by_id"
  add_foreign_key "split_expenses", "expenses"
  add_foreign_key "split_expenses", "users"
end
