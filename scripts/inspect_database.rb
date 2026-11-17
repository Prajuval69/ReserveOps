# frozen_string_literal: true

connection = ActiveRecord::Base.connection
constraint = connection.select_value("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='no_active_resource_overlap'")
raise 'Exclusion constraint is missing' unless constraint&.include?('EXCLUDE USING gist')

superuser = connection.select_value('SELECT rolsuper FROM pg_roles WHERE rolname=current_user')
raise 'Runtime role must not be superuser' if superuser

puts({ database: connection.current_database, superuser: superuser, users: User.count, resources: Resource.count,
       bookings: Booking.count, exclusion: constraint, timestamp_type: Booking.columns_hash['starts_at'].sql_type }.to_json)
