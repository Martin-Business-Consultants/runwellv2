# Runwell's patches to Rails and its gems, one file each in lib/rails_ext (Fizzy's layout): what
# each changes and why is at the top of its file.
Dir[Rails.root.join("lib/rails_ext/*.rb")].sort.each { |path| require path }
