require "json"

require "./storage/file_system"

class UploadedFile
  class Metadata
    JSON.mapping(
      size: {type: UInt64, nilable: true, emit_null: true},
      mime_type: {type: String, nilable: true, emit_null: true},
      filename: {type: String, nilable: true, emit_null: true}
    )

    def initialize; end

    def initialize(data : NamedTuple)
      @size = data[:size]?.try &.to_u64
      @mime_type = data[:mime_type]?
      @filename = data[:filename]?
    end

    def data
      {
        size:      size,
        mime_type: mime_type,
        filename:  filename,
      }
    end
  end

  getter file : File?

  JSON.mapping(
    id: {type: String},
    storage_key: {type: String},
    metadata: {type: UploadedFile::Metadata}
  )

  def initialize(id : String, storage : String, metadata : NamedTuple = NamedTuple.new)
    @storage_key = storage
    @metadata = UploadedFile::Metadata.new(metadata)

    @id = id
  end

  def initialize(id : String, storage : Symbol, metadata : NamedTuple = NamedTuple.new)
    initialize(id, storage.to_s, metadata)
  end

  delegate size, to: @metadata
  delegate mime_type, to: @metadata

  delegate pos, to: file
  delegate gets_to_end, to: file

  # delegate close, to: file
  # delegate path, to: file

  def extension
    result = File.extname(id)[1..-1]?
    result ||= File.extname(original_filename.not_nil!)[1..-1]? if original_filename
    result = result.downcase if result

    result
  end

  def original_filename
    metadata.filename if metadata
  end

  # Shorthand for accessing metadata values.
  def [](key)
    metadata[key]?
  end

  # Calls `#url` on the storage, forwarding any given URL options.
  def url(**options)
    storage.url(id, options)
  end

  # Calls `#exists?` on the storage, which checks whether the file exists
  # on the storage.
  def exists?
    storage.exists?(id)
  end

  # Returns the storage that this file was uploaded to.
  def storage
    Shrine.find_storage(storage_key.not_nil!).not_nil!
  end

  private def file
    (@file ||= _open).not_nil!
  end

  private def _open(**options)
    storage.open(id)
  end
end
