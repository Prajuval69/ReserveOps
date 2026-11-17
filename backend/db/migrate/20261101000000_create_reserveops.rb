# frozen_string_literal: true

class CreateReserveops < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'btree_gist'
    create_table :users do |t|
      t.string :email, :password_digest, :display_name, null: false
      t.string :role, default: 'employee', null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :users, 'lower(email)', unique: true
    add_check_constraint :users, "role IN ('employee','manager','admin')", name: 'valid_user_role'
    add_check_constraint :users, 'email = lower(email)', name: 'normalized_email'
    create_table :locations do |t|
      t.string :name, null: false
      t.string :timezone, default: 'Asia/Kolkata', null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :locations, :name, unique: true
    create_table :manager_location_scopes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
    end
    add_index :manager_location_scopes, %i[user_id location_id], unique: true
    create_table :resource_categories do |t|
      t.string :name, :slug, null: false
      t.timestamps
    end
    add_index :resource_categories, :slug, unique: true
    create_table :resources do |t|
      t.references :resource_category, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.string :name, :identifier, null: false
      t.text :description, default: '', null: false
      t.integer :occupants_capacity, default: 1, null: false
      t.boolean :requires_approval, default: false, null: false
      t.integer :min_minutes, default: 15, null: false
      t.integer :max_minutes, default: 480, null: false
      t.integer :advance_days, default: 60, null: false
      t.string :opens_at, default: '08:00', null: false
      t.string :closes_at, default: '20:00', null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :resources, %i[location_id identifier], unique: true
    add_check_constraint :resources, 'occupants_capacity > 0 AND min_minutes > 0 AND max_minutes >= min_minutes AND advance_days > 0',
                         name: 'valid_resource_policy'
    add_check_constraint :resources, "opens_at ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND closes_at ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND opens_at < closes_at",
                         name: 'valid_opening_hours'
    create_table :resource_blackouts do |t|
      t.references :resource, null: false, foreign_key: true
      t.datetime :starts_at, :ends_at, null: false
      t.string :reason, null: false
      t.timestamps
    end
    add_check_constraint :resource_blackouts, 'ends_at > starts_at', name: 'positive_blackout'
    create_table :bookings do |t|
      t.references :user, :resource, null: false, foreign_key: true
      t.datetime :starts_at, :ends_at, null: false
      t.string :status, null: false
      t.integer :attendee_count, default: 1, null: false
      t.string :purpose, null: false
      t.datetime :approval_expires_at, :decided_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.text :cancellation_reason
      t.timestamps
    end
    add_check_constraint :bookings, 'ends_at > starts_at', name: 'positive_booking_interval'
    add_check_constraint :bookings, 'attendee_count >= 1', name: 'positive_attendee_count'
    add_check_constraint :bookings, "status IN ('pending_approval','confirmed','waitlisted','rejected','cancelled','expired','completed')",
                         name: 'valid_booking_status'
    add_check_constraint :bookings, "status != 'pending_approval' OR (approval_expires_at IS NOT NULL AND approval_expires_at <= starts_at)",
                         name: 'valid_hold_deadline'
    add_index :bookings, %i[resource_id starts_at ends_at]
    add_index :bookings, %i[user_id created_at]
    add_index :bookings, %i[status approval_expires_at]
    add_index :bookings, %i[user_id resource_id starts_at ends_at], unique: true,
                                                                    where: "status = 'waitlisted'", name: 'one_waitlist_entry'
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE bookings ADD CONSTRAINT no_active_resource_overlap
          EXCLUDE USING gist (resource_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
          WHERE (status IN ('pending_approval', 'confirmed'));
        SQL
      end
      dir.down { execute 'ALTER TABLE bookings DROP CONSTRAINT no_active_resource_overlap' }
    end
    create_table :booking_events do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :from_status, :to_status
      t.string :action, null: false
      t.jsonb :metadata, default: {}, null: false
      t.datetime :created_at, null: false
    end
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :booking, foreign_key: true
      t.string :notification_key, :kind, :title, null: false
      t.text :body, null: false
      t.datetime :read_at
      t.datetime :created_at, null: false
    end
    add_index :notifications, %i[user_id notification_key], unique: true
    add_index :notifications, %i[user_id read_at created_at]
  end
end
