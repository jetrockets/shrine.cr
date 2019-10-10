ENV["AMBER_ENV"] ||= "test"

require "spectator"

# require "garnet_spec"

# require "../config/application"
require "../src//*"
require "./support/file_helpers"
require "./support/shrine_helpers"
require "./support/have_permissions_matcher"

# Micrate::DB.connection_url = Amber.settings.database_url

# Automatically run migrations on the test database
# Micrate::Cli.run_up
# Disable Granite logs in tests
# Granite.settings.logger = Amber.settings.logger.dup

Spectator.configure do |config|
  config.randomize # Randomize test order.
  # config.profile   # Display slowest tests.
end
