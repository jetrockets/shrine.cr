require "json"

class Shrine
  class UploadedFile
    include JSON::Serializable

    alias MetadataType = Hash(String, String | Int32 | UInt32 | Int64 | UInt64 | Nil)

    @io : IO?

    property id : String
    property storage_key : String
    property metadata : MetadataType

    def initialize(id : String, storage : String, metadata : MetadataType = MetadataType.new)
      @storage_key = storage
      @metadata = metadata

      @id = id
    end

    def initialize(id : String, storage : Symbol, metadata : MetadataType = MetadataType.new)
      initialize(id, storage.to_s, metadata)
    end

    delegate pos, to: io
    delegate gets_to_end, to: io

    def extension
      result = File.extname(id)[1..-1]?
      result ||= File.extname(original_filename.not_nil!)[1..-1]? if original_filename
      result = result.downcase if result

      result
    end

    def size
      metadata["size"]?.try &.to_i
    rescue ArgumentError
      nil
    end

    def mime_type
      metadata["mime_type"]?.try &.to_s
    end

    def content_type
      mime_type
    end

    def original_filename
      metadata["filename"]?.try &.to_s
    end

    # Shorthand for accessing metadata values.
    def [](key)
      metadata[key]?
    end

    # Calls `#open` on the storage to open the uploaded file for reading.
    # Most storages will return a lazy IO object which dynamically
    # retrieves file content from the storage as the object is being read.
    #
    # If a block is given, the opened IO object is yielded to the block,
    # and at the end of the block it's automatically closed. In this case
    # the return value of the method is the block return value.
    #
    # If no block is given, the opened IO object is returned.
    #
    # ```
    # uploaded_file.open # => IO object returned by the storage
    # uploaded_file.read # => "..."
    # uploaded_file.close
    #
    # # or
    #
    # uploaded_file.open { |io| io.read } # the IO is automatically closed
    # ```
    #
    def open(**options)
      @io.not_nil!.close if @io
      @io = _open(**options)
    end

    def open(**options, &block)
      open(**options)

      begin
        yield @io.not_nil!
      ensure
        close
        @io = nil
      end
    end

    # Streams content into a newly created tempfile and returns it.
    #
    # ```
    # uploaded_file.download
    # # => #<File:/var/folders/.../20180302-33119-1h1vjbq.jpg>
    # ```
    #
    def download(**options)
      tempfile = File.tempfile("shrine", ".#{extension}")
      stream(tempfile, **options)
      tempfile.rewind
    end

    # Streams content into a newly created tempfile, yields it to the
    # block, and at the end of the block automatically closes it.
    # In this case the return value of the method is the block
    # return value.
    #
    # ```
    # uploaded_file.download { |tempfile| tempfile.gets_to_end } # tempfile is deleted
    # ```
    #
    def download(**options, &block)
      tempfile = download(**options)
      yield(tempfile)
    ensure
      if tempfile
        tempfile.not_nil!.close
        tempfile.not_nil!.delete
      end
    end

    # Streams uploaded file content into the specified destination. The
    # destination object is given directly to `IO.copy`.
    #
    # If the uploaded file is already opened, it will be simply rewinded
    # after streaming finishes. Otherwise the uploaded file is opened and
    # then closed after streaming.
    #
    # ```
    # uploaded_file.stream(IO::Memory.new)
    # ```
    def stream(destination : IO, **options)
      if opened?
        IO.copy(io, destination)
        io.rewind
      else
        open(**options) { |io| IO.copy(io, destination) }
      end
    end

    # Part of complying to the IO interface. It delegates to the internally
    # opened IO object.
    def close
      io.close if opened?
    end

    # Returns whether the file has already been opened.
    def opened?
      !!@io
    end

    # Calls `#url` on the storage, forwarding any given URL options.
    def url(**options) : String
      storage.url(id, **options)
    end

    # Calls `#exists?` on the storage, which checks whether the file exists
    # on the storage.
    def exists?
      storage.exists?(id)
    end

    # Uploads a new file to this file's location and returns it.
    def replace(io, **options)
      uploader.upload(io, **options, location: id)
    end

    # Calls `#delete` on the storage, which deletes the file from the
    # storage.
    def delete
      storage.delete(id)
    end

    # Returns an uploader object for the corresponding storage.
    def uploader
      Shrine.new(storage_key)
    end

    # Returns the storage that this file was uploaded to.
    def storage : Shrine::Storage::Base
      Shrine.find_storage(storage_key.not_nil!).not_nil!
    end

    def io : IO
      (@io ||= _open).not_nil!
    end

    # Returns serializable hash representation of the uploaded file.
    def data : Hash(String, String | MetadataType)
      {"id" => id, "storage" => storage_key, "metadata" => metadata}
    end

    private def _open(**options)
      storage.open(id)
    end
  end
end
