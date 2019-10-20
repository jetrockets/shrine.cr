require "spectator"

require "../src/*"
require "./support/file_helpers"
require "./support/shrine_helpers"
require "./support/have_permissions_matcher"

Spectator.configure do |config|
  config.randomize # Randomize test order.
end
