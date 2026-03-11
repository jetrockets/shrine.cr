# shrine/src/attacher.cr (Crystal, not Ruby!)

class Shrine
  # Manages file attachments from upload to storage
  class Attacher
    # The currently attached file
    getter file : UploadedFile?
    
    # Storage locations (as symbols, not magic strings)
    @cache_storage : Symbol = :cache
    @store_storage : Symbol = :store

    def initialize(@cache_storage = :cache, @store_storage = :store)
      @previous_file = nil
    end

    # Attach a file (from upload, form, etc.)
    def attach(io : IO) : UploadedFile
      file = shrine_class.upload(io, @cache_storage)
      @previous_file = @file
      @file = file
    end

    # Move from cache to permanent storage
    def promote : UploadedFile
      return unless file = @file
      
      stored = shrine_class.upload(file, @store_storage)
      @previous_file.try(&.delete)
      @file = stored
    end

    # Remove the file
    def destroy
      @file.try(&.delete)
      @file = nil
    end

    # Load from database data
    def from_json(data : String)
      @file = UploadedFile.from_json(data)
    end

    # Save to database
    def to_json : String?
      @file.try(&.to_json)
    end

    # Check if file exists
    def exists? : Bool
      @file.try(&.exists?) || false
    end

    # Get URL (with options)
    def url(**options) : String?
      @file.try(&.url(**options))
    end
  end
en