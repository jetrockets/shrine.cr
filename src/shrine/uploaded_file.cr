require "json"

class Shrine
  class UploadedFile
    include JSON::Serializable

    alias MetadataType = Hash(String, String | Int16 | UInt16 | Int32 | UInt32 | Int64 | UInt64 | Nil)

    struct Mapper
      include JSON::Serializable

      getter id : String
      getter storage_key : String
      getter metadata : MetadataType

      def initialize(@id, @storage_key, @metadata)
      end
    end

    {% begin %}
      {% for method in %w[id storage_key metadata to_json] %}
        delegate {{method.id}}, to: @mapper
      {% end %}
    {% end %}

    @io : IO?
    @mapper : Mapper

    def self.from_json(json : String)
      new(Mapper.from_json(json))
    end

    def initialize(@mapper : Mapper)
    end

    def initialize(id : String, storage_key : String, metadata : MetadataType = MetadataType.new)
      @mapper = Mapper.new(id: id, storage_key: storage_key, metadata: metadata)
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
      {"id" => id, "storage_key" => storage_key, "metadata" => metadata}
    end

    # Returns true if the other UploadedFile is uploaded to the same
    # storage and it has the same #id.
    def ==(other : UploadedFile)
      self.class == other.class &&
        self.id == other.id &&
        self.storage_key == other.storage_key
    end

    private def _open(**options)
      storage.open(id)
    end
  end
end
