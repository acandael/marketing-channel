namespace :admin do
  desc "Create an admin user. Set ADMIN_EMAIL and ADMIN_PASSWORD env vars, or you'll be prompted."
  task create: :environment do
    require "io/console"

    email = ENV["ADMIN_EMAIL"].presence
    unless email
      print "Admin email: "
      email = $stdin.gets.to_s.strip
    end

    password = ENV["ADMIN_PASSWORD"].presence
    unless password
      print "Admin password (min 8 chars): "
      password = $stdin.noecho(&:gets).to_s.strip
      puts
    end

    if email.blank? || password.blank?
      abort "Email and password are required."
    end

    user = User.find_or_initialize_by(email_address: email)
    user.password = password
    user.role = :admin
    if user.save
      puts "Admin ready: #{user.email_address}"
    else
      abort "Could not save admin: #{user.errors.full_messages.to_sentence}"
    end
  end
end
