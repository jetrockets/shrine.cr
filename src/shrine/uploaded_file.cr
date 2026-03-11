require "json"

class Shrine
  class UploadedFile
    include JSON::Serializable

    alias MetadataType = Hash(String, String | Int64 | Nil)

    # Simple struct for data
    struct Data
      include JSON::Serializable
      property id : String
      property storage_key : String
      property metadata : MetadataType
    end

    # Delegate methods (simple!)
    delegate id, storage_key, metadata, to_json, to: @data
    
    @io : IO?

    def initialize(@data : Data); end
    
    def initialize(id : String, storage_key : String, metadata : MetadataType = MetadataType.new)
      @data = Data.new(id: id, storage_key: storage_key, metadata: metadata)
    end

    # Everything else stays the same...
    # (all the actual useful methods)
  end
end