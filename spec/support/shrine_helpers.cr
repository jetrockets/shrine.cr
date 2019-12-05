module ShrineHelpers
  # def shrine
  #   uploader_class = Shrine

  #   uploader_class.settings.storages["cache"] = Shrine::Storage::Memory.new
  #   uploader_class.settings.storages["store"] = Shrine::Storage::Memory.new

  #   uploader_class
  # end

  def uploader(storage_key = "store")
    Shrine.new(storage_key)
  end
end
