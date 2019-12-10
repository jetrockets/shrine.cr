require "spectator"
require "webmock"

require "../src/*"
require "./support/file_helpers"
require "./support/shrine_helpers"
require "./support/have_permissions_matcher"

Spectator.configure do |config|
  config.randomize # Randomize test order.
end

Shrine.configure do |config|
  config.storages["cache"] = Shrine::Storage::Memory.new
  config.storages["store"] = Shrine::Storage::Memory.new
  config.storages["other_cache"] = Shrine::Storage::Memory.new
  config.storages["other_store"] = Shrine::Storage::Memory.new
end

Shrine.raise_if_missing_settings!

def clear_storages
  Shrine.settings.storages["cache"].as(Shrine::Storage::Memory).clear!
  Shrine.settings.storages["store"].as(Shrine::Storage::Memory).clear!
  Shrine.settings.storages["other_cache"].as(Shrine::Storage::Memory).clear!
  Shrine.settings.storages["other_store"].as(Shrine::Storage::Memory).clear!
end
