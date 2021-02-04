require "./shrine/storage/*"
require "./shrine/attacher"
require "./shrine/uploaded_file"

require "habitat"

require "log"

Log.setup_from_env

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

  # Raised by the attacher when assigned uploaded file is not cached.
  class NotCached < Error
  end

  Habitat.create do
    setting storages : Hash(String, Storage::Base) = Hash(String, Storage::Base).new
  end

  struct PluginSettings
    def all
      [] of Nil
    end
  end

  def self.plugin_settings
    PluginSettings.new
  end

  macro inherited
    {{@type}}::PLUGINS = [] of Nil

    {% for plugin in @type.superclass.constant(:PLUGINS) %}
      load_plugin({{plugin[:decl]}}, {{plugin[:options].double_splat}})
    {% end %}

    class Attacher < Shrine::Attacher
      def self.shrine_class
        {{ @type }}
      end
    end

    # class UploadedFile
    #   def self.shrine_class
    #     {{ @type }}
    #   end
    # end
  end

  macro load_plugin(plugin, **args)
    {% plugin = plugin.resolve %}
    {% options = args %}

    {% if PLUGINS.map { |e| e[:decl] }.includes?(plugin) %}
      raise ArgumentError.new("Cannot load plugin {{plugin.stringify}} to {{@type}}. Plugin has already been initialized")
    {% else %}
      {% if plugin.constant(:DEFAULT_OPTIONS) %}
        {% if !options %}
          {% options = plugin.constant(:DEFAULT_OPTIONS) %}
        {% end %}

        {% for key in plugin.constant(:DEFAULT_OPTIONS).keys %}
          {% unless options[key] %}
            {{ options[key] = plugin.constant(:DEFAULT_OPTIONS)[key] }}
          {% end %}
        {% end %}
      {% end %}

      {% PLUGINS << {decl: plugin, options: options} %}
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

    {% if plugin.constant(:AttacherClassMethods) %}
      class Attacher < Shrine::Attacher
        extend {{plugin.constant(:AttacherClassMethods)}}
      end
    {% end %}

    {% if plugin.constant(:AttacherMethods) %}
      class Attacher < Shrine::Attacher
        include {{plugin.constant(:AttacherMethods)}}
      end
    {% end %}
  end

  macro finalize_plugins!
    class PluginsSettings
      def all
        {% if @type.constant(:PLUGINS) %}
          {{
            @type.constant(:PLUGINS).map do |plugin|
              options = (plugin[:options].empty? ? nil : plugin[:options])

              {
                name:    plugin[:decl].stringify.underscore.split("::").last,
                options: options,
              }
            end
          }}
        {% end %}
      end

      def [](key : Symbol | String)
        all.find{ |plugin| plugin[:name] == key.to_s}.try &.[:options]
      end

      {% for plugin in @type.constant(:PLUGINS) %}
        def {{ plugin[:decl].stringify.underscore.split("::").last.id }}
          {% if plugin[:options].empty? %}
            nil
          {% else %}
            {{ plugin[:options] }}
          {% end %}
        end
      {% end %}
    end

    def self.plugin_settings
      PluginsSettings.new
    end
  end

  module ClassMethods
    macro extended
      Log = ::Log.for("shrine.cr")
    end

    # Retrieves the storage under the given identifier (Symbol), raising Shrine::Error if the storage is missing.
    def find_storage(name : String)
      settings.storages[name]? || raise Error.new("storage #{name.inspect} isn't registered on #{self}")
    end

    # Uploads the file to the specified storage. It delegates to `Shrine#upload`.
    #
    # ```
    # Shrine.upload(io, :store) # => #<Shrine::UploadedFile>
    # ```
    def upload(io, storage, **options)
      new(storage).upload(io, **options)
    end

    def cache(io, **options)
      new("cache").upload(io, **options)
    end

    def store(io, **options)
      new("store").upload(io, **options)
    end

    def raise_if_missing_settings!
      Habitat.raise_if_missing_settings!
    end

    def uploaded_file(hash : Hash(String, String | UploadedFile::MetadataType))
      self.uploaded_file(hash.to_json)
    end

    def uploaded_file(json : String)
      UploadedFile.from_json(json)
    end

    def uploaded_file(object : UploadedFile)
      object
    end

    # Temporarily converts an IO-like object into a file. If the input IO object
    # is already a file, it simply yields it to the block, otherwise it copies
    # IO content into a Tempfile object which is then yielded and afterwards
    # deleted.
    #
    # ```
    # Shrine.with_file(io) { |file| file.path }
    # ```
    #
    def with_file(io : IO)
      if io.responds_to?(:path)
        yield io
      else
        File.tempfile("shrine-file") do |file|
          File.write(file.path, io.gets_to_end)
          io.rewind
          yield file
        end
      end
    end

    def with_file(uploaded_file : UploadedFile)
      uploaded_file.download do |tempfile|
        yield tempfile
      end
    end

    # Prints a warning to the logger.
    def warn(message)
      Log.warn { "SHRINE WARNING: #{message}" }
    end
  end

  module InstanceMethods
    getter storage_key : String

    def initialize(@storage_key : String)
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
    def upload(io : IO | UploadedFile, **options)
      metadata = get_metadata(io, **options)
      location = get_location(io, **options.merge(metadata: metadata))

      _upload(io, **options.merge(location: location, metadata: metadata))

      UploadedFile.new(
        id: location,
        storage_key: storage_key,
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
      Log.warn { "SHRINE WARNING: #{message}" }
    end

    # Extracts filename, size and MIME type from the file, which is later
    # accessible through UploadedFile#metadata.
    private def extract_metadata(io, **options) : Shrine::UploadedFile::MetadataType
      hash = Shrine::UploadedFile::MetadataType.new
      hash["filename"] = extract_filename(io)
      hash["size"] = extract_size(io)
      hash["mime_type"] = extract_mime_type(io)
      hash
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
      if io.responds_to?(:content_type) && io.content_type
        Shrine.warn "The \"mime_type\" Shrine metadata field will be set from the \"Content-Type\" request header, which might not hold the actual MIME type of the file. It is recommended to load the determine_mime_type plugin which determines MIME type from file content."
        io.content_type.not_nil!.split(';').first # exclude media type parameters
      end
    end

    private def extract_mime_type(io : UploadedFile)
      io.metadata.mime_type
    end

    # Generates a basic location for an uploaded file
    private def basic_location(io, metadata : UploadedFile::MetadataType)
      extension = ".#{io.extension}" if io.is_a?(UploadedFile) && io.extension
      extension ||= File.extname(metadata["filename"].as(String)) if metadata["filename"]?
      basename = generate_uid(io)

      extension ? basename + extension : basename
    end

    # If the IO object is a Shrine::UploadedFile, it simply copies over its
    # metadata, otherwise it calls #extract_metadata.
    private def get_metadata(io : IO, metadata : UploadedFile::MetadataType? = nil, **options)
      result = extract_metadata(io)
      result = result.merge(metadata) if metadata
      result
    end

    private def get_metadata(io : UploadedFile, metadata : UploadedFile::MetadataType? = nil, **options)
      result = io.metadata
      result = result.merge(metadata) if metadata
      result
    end

    # Retrieves the location for the given IO and context. First it looks
    # for the `:location` option, otherwise it calls #generate_location.
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
end
