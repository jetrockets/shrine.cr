module ShrineHelpers
  def shrine
    uploader_class = Shrine
    uploader_class.settings.storages["cache"] = Storage::Memory.new
    uploader_class.settings.storages["store"] = Storage::Memory.new

    uploader_class
  end

  def uploader(storage_key = :store)
    shrine.new(storage_key)
  end
end