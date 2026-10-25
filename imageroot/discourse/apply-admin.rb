# Create or update the NS8 managed admin account. Read by "rails runner -" from stdin.
email = ENV.fetch("NS8_ADMIN_EMAIL")
username = ENV.fetch("NS8_ADMIN_USERNAME")
password = ENV["NS8_ADMIN_PASSWORD"].to_s

user = User.find_by(id: ENV["NS8_ADMIN_ID"].to_i) if ENV["NS8_ADMIN_ID"].to_s != ""
user ||= User.find_by_email(email)
if user.nil? && password == ""
  # The managed account was deleted in Discourse: never create an admin nobody can log in with
  puts "NS8_ADMIN_NEEDS_PASSWORD"
  exit 4
end
user ||= User.new(name: username)

# Renaming the admin onto an account that already exists would fail on save!
other = User.find_by_username(username)
if other && other.id != user.id
  warn "NS8_ADMIN_ERROR username #{username} belongs to another account"
  exit 3
end
other = User.find_by_email(email)
if other && other.id != user.id
  warn "NS8_ADMIN_ERROR email #{email} belongs to another account"
  exit 3
end
user.username = username if user.username != username
user.email = email if user.email != email
# Discourse refuses to reuse the current password: an identical one is already applied
user.password = password if password != "" && !(user.persisted? && user.confirm_password?(password))
user.active = true
user.approved = true
user.save!
user.activate
user.grant_admin! unless user.admin?
user.email_tokens.update_all(confirmed: true)
puts "NS8_ADMIN_APPLIED=#{user.id}"
