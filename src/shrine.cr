require "./shrine/storage/*"
require "./shrine/uploaded_file"

require "habitat"

require "logger"

class Shrine
  PLUGINS = [] of Nil

  class Error < Exception; end

  # Raised when a file is not a valid IO.
  class InvalidFile < Error
    def initialize(io, missing_methods)
      super "#{io.inspect} is not a valid IO object (it doesn't respond to #{missing_methods.map { |m, _| "##{m}" }.join(", ")})"
    end
  end

  # Raised by the storage in the #open method.
  class FileNotFound < Error
  end

  Habitat.create do
    setting storages : Hash(String, Storage::Base) = Hash(String, Storage::Base).new
    setting log_level : Logger::Severity = Logger::WARN
  end

  macro inherited
    {{@type}}::PLUGINS = [] of Nil
 
    {% for plugin in @type.superclass.constant(:PLUGINS) %}
      load_plugin({{plugin}})
    {% end %}
  end

  macro load_plugin(plugin)
    {% plugin = plugin.resolve %}
  
    {% if PLUGINS.includes?(plugin) %}
      raise ArgumentError.new("Cannot load plugin {{plugin.stringify}} to {{@type}}. Plugin has already been initialized")
    {% else %}
      {% PLUGINS << plugin %}
    {% end %}
    
    {% if plugin.constant(:InstanceMethods) %}
      include {{plugin.constant(:InstanceMethods)}}
    {% end %}
 
    {% if plugin.constant(:ClassMethods) %}
      extend {{plugin.constant(:ClassMethods)}}
    {% end %}

    {% if plugin.constant(:FileClassMethods) %}
      class UploadedFile < Shrine::UploadedFile
        extend {{plugin.constant(:FileClassMethods)}}
      end
    {% end %}

    {% if plugin.constant(:FileMethods) %}
      class UploadedFile < Shrine::UploadedFile
        include {{plugin.constant(:FileMethods)}}
      end
    {% end %}
  end

  macro create_plugins_class_method
    def self.plugins
      {% if @type.constant(:PLUGINS) %}
        {{@type.constant(:PLUGINS).map &.stringify}}
      {% end %}
    end
  end

  module ClassMethods
    macro extended
      class_property logger = Logger.new(STDOUT, level: settings.log_level)
    end

    # Retrieves the storage under the given identifier (Symbol), raising Shrine::Error if the storage is missing.
    def find_storage(name : String | Symbol)
      settings.storages[name.to_s]? || raise Error.new("storage #{name.inspect} isn't registered on #{self}")
    end

    # Uploads the file to the specified storage. It delegates to `Shrine#upload`.
    #
    #     Shrine.upload(io, :store) #=> #<Shrine::UploadedFile>
    def upload(io, storage, **options)
      new(storage).upload(io, **options)
    end
  end

  module InstanceMethods
    getter storage_key : Symbol

    def initialize(@storage_key : Symbol)
    end

    # Returns the storage object referenced by the identifier.
    def storage
      self.class.find_storage(storage_key)
    end

    # The main method for uploading files. Takes an IO-like object and an
    # optional context hash (used internally by Shrine::Attacher). It calls
    # user-defined #process, and afterwards it calls #store. The `io` is
    # closed after upload.
    #
    #   uploader.upload(io)
    #   uploader.upload(io, metadata: { "foo" => "bar" })           # add metadata
    #   uploader.upload(io, location: "path/to/file")               # specify location
    #   uploader.upload(io, upload_options: { acl: "public-read" }) # add upload options
    # def upload(io : IO | UploadedFile, options : NamedTuple? = NamedTuple.new)
    def upload(io : IO | UploadedFile, **options)
      metadata = get_metadata(io, **options)
      # location = get_location(io, metadata: metadata, location: options[:location]?, context: options[:context]?)
      location = get_location(io, **options.merge(metadata: metadata))

      _upload(io, **options.merge(location: location, metadata: metadata))

      UploadedFile.new(
        id: location,
        storage: storage_key,
        metadata: metadata,
      )
    end

    # Generates a unique location for the uploaded file, preserving the
    # file extension. Can be overriden in uploaders for generating custom
    # location.
    def generate_location(io : IO | UploadedFile, metadata, **options)
      basic_location(io, metadata: metadata)
    end

    # Prints a warning to the logger.
    def warn(message)
      Shrine.logger.warn "SHRINE WARNING: #{message}"
    end

    # Extracts filename, size and MIME type from the file, which is later
    # accessible through UploadedFile#metadata.
    private def extract_metadata(io)
      {
        filename:  extract_filename(io),
        size:      extract_size(io),
        mime_type: extract_mime_type(io),
      }
    end

    # private def _upload(io : IO, location, metadata, upload_options, close = true, delete = false)
    private def _upload(io : IO | UploadedFile, location, metadata, close = true, delete = false, **options)
      storage.upload(io, location, **options.merge(metadata: metadata))
    ensure
      io.close if close
      File.delete(io.path) if delete && io.responds_to?(:path) && File.exists?(io.path)
    end

    # Attempts to extract the appropriate filename from the IO object.
    private def extract_filename(io)
      if io.responds_to?(:original_filename)
        io.original_filename
      elsif io.responds_to?(:path)
        File.basename(io.path)
      end
    end

    # Extracts the filesize from the IO object.
    private def extract_size(io)
      io.size if io.responds_to?(:size)
    end

    # Attempts to extract the MIME type from the IO object.
    private def extract_mime_type(io : IO)
      # if io.responds_to?(:content_type) && io.content_type
      #   # Shrine.warn "The \"mime_type\" Shrine metadata field will be set from the \"Content-Type\" request header, which might not hold the actual MIME type of the file. It is recommended to load the determine_mime_type plugin which determines MIME type from file content."
      #   io.content_type.split(";").first # exclude media type parameters
      # end

      return nil if io.size.try &.zero? # file command returns "application/x-empty" for empty files

      stdout = IO::Memory.new
      stderr = IO::Memory.new
      status = Process.run("file", args: ["--mime-type", "--brief", "-"], output: stdout, error: stderr, input: io)

      if status.success?
        io.rewind
        stdout.to_s.strip
      else
        raise Error.new "file command failed: #{stderr.to_s}"
      end
    end

    private def extract_mime_type(io : UploadedFile)
      io.metadata.mime_type
    end

    # Generates a basic location for an uploaded file
    private def basic_location(io, metadata : NamedTuple)
      extension = ".#{io.extension}" if io.is_a?(UploadedFile) && io.extension
      extension ||= File.extname(metadata["filename"].not_nil!) if metadata["filename"]?
      basename = generate_uid(io)

      extension ? basename + extension : basename
    end

    # If the IO object is a Shrine::UploadedFile, it simply copies over its
    # metadata, otherwise it calls #extract_metadata.
    private def get_metadata(io : IO, metadata : NamedTuple? = nil, **options)
      result = extract_metadata(io)
      result = result.merge(metadata) if metadata
      result
    end

    private def get_metadata(io : UploadedFile, metadata : NamedTuple? = nil, **options)
      result = io.metadata.data
      result = result.merge(metadata) if metadata
      result
    end

    # Retrieves the location for the given IO and context. First it looks
    # for the `:location` option, otherwise it calls #generate_location.
    # private def get_location(io : IO, metadata : Hash(String, String | Nil), location : String? = nil)
    # private def get_location(io : IO | UploadedFile, metadata : NamedTuple, context : NamedTuple?, location : String? = nil)
    private def get_location(io, location : String? = nil, **options)
      location ||= generate_location(io, **options)
      raise Error.new("location generated for #{io.inspect} was nil") if location.nil?

      location
    end

    # Generates a unique identifier that can be used for a location.
    def generate_uid(io)
      Random.new.hex
    end
  end

  include InstanceMethods
  extend ClassMethods

  Habitat.raise_if_missing_settings!
end
