# frozen_string_literal: true

class Shrine
  # Core class that handles attaching files. It uses Shrine and
  # Shrine::UploadedFile objects internally.
  class Attacher
    # Returns the Shrine class that this attacher class is namespaced
    # under.
    class_getter shrine_class : Shrine.class = Shrine

    module ClassMethods
      # Initializes the attacher from a data hash generated from `Attacher#data`.
      #
      #     attacher = Attacher.from_data({ "id" => "...", "storage" => "...", "metadata" => { ... } })
      #     attacher.file #=> #<Shrine::UploadedFile>
      def from_data(data : Hash(String, String | UploadedFile::MetadataType)?, **options)
        attacher = new(**options)
        attacher.load_data(data)
        attacher
      end
    end

    module InstanceMethods
      # Returns the attached uploaded file.
      property file : Shrine::UploadedFile?

      # Returns options that are automatically forwarded to the uploader.
      # Can be modified with additional data.
      getter :context

      getter :cache_key
      getter :store_key

      @previous : Shrine::Attacher?

      # Initializes the attached file, temporary and permanent storage.
      def initialize(@file : Shrine::UploadedFile? = nil, @cache_key : String = "cache", @store_key : String = "store")
        @file = file
        @cache_key = cache_key
        @store_key = store_key
        @context = Hash(String, String).new
      end

      # Calls #attach_cached, but skips if value is an empty string (this is
      # useful when the uploaded file comes from form fields). Forwards any
      # additional options to #attach_cached.
      #
      #     attacher.assign(File.open(...))
      #     attacher.assign(File.open(...), metadata: { "foo" => "bar" })
      #
      #     # ignores the assignment when a blank string is given
      #     attacher.assign("")
      def assign(value : IO?, **options)
        # return if value == "" # skip empty hidden field

        attach_cached(value, **options)
      end

      # Sets an existing cached file, or uploads an IO object to temporary
      # storage and sets it via #attach. Forwards any additional options to
      # #attach.
      #
      #     # upload file to temporary storage and set the uploaded file.
      #     attacher.attach_cached(File.open(...))
      #
      #     # foward additional options to the uploader
      #     attacher.attach_cached(File.open(...), metadata: { "foo" => "bar" })
      #
      #     # sets an existing cached file from JSON data
      #     attacher.attach_cached("{\"id\":\"...\",\"storage\":\"cache\",\"metadata\ ":{...}}")
      #
      #     # sets an existing cached file from Hash data
      #     attacher.attach_cached({ "id" => "...", "storage" => "cache", "metadata" => {} })
      def attach_cached(value : IO | UploadedFile | Nil, **options)
        attach(value, **options.merge(storage: cache_key, action: :cache))
      end

      def attach_cached(value : String | Hash(String, String | UploadedFile::MetadataType), **options)
        change(cached(value, **options))
      end

      # Uploads given IO object and changes the uploaded file.
      #
      #     # uploads the file to permanent storage
      #     attacher.attach(io)
      #
      #     # uploads the file to specified storage
      #     attacher.attach(io, storage: :other_store)
      #
      #     # forwards additional options to the uploader
      #     attacher.attach(io, upload_options: { "x-amz-acl": "public-read" }, metadata: { "foo" => "bar" })
      #
      #     # removes the attachment
      #     attacher.attach(nil)
      def attach(io : IO | Shrine::UploadedFile | Nil, storage = store_key, **options) : UploadedFile | Nil
        file = upload(io, storage, **options) if io

        change(file)
      end

      # Deletes any previous file and promotes newly attached cached file.
      # It also clears any dirty tracking.
      #
      #     # promoting cached file
      #     attacher.assign(io)
      #     attacher.cached? #=> true
      #     attacher.finalize
      #     attacher.stored?
      #
      #     # deleting previous file
      #     previous_file = attacher.file
      #     previous_file.exists? #=> true
      #     attacher.assign(io)
      #     attacher.finalize
      #     previous_file.exists? #=> false
      #
      #     # clearing dirty tracking
      #     attacher.assign(io)
      #     attacher.changed? #=> true
      #     attacher.finalize
      #     attacher.changed? #=> false
      def finalize
        destroy_previous
        promote_cached
        @previous = nil if changed?
      end

      # If a new cached file has been attached, uploads it to permanent storage.
      # Any additional options are forwarded to #promote.
      #
      #     attacher.assign(io)
      #     attacher.cached? #=> true
      #     attacher.promote_cached
      #     attacher.stored? #=> true
      def promote_cached(**options)
        promote(**options) if promote?
      end

      # Uploads current file to permanent storage and sets the stored file.
      #
      #     attacher.cached? #=> true
      #     attacher.promote
      #     attacher.stored? #=> true
      def promote(storage = store_key, **options) : Shrine::UploadedFile | Nil
        set upload(file.not_nil!, storage, **options.merge(action: :store)) if file
      end

      # Delegates to `Shrine.upload`, passing the #context.
      #
      #     # upload file to specified storage
      #     attacher.upload(io, "store") #=> #<Shrine::UploadedFile>
      #
      #     # pass additional options for the uploader
      #     attacher.upload(io, "store", metadata: { "foo" => "bar" })
      def upload(io : IO | Shrine::UploadedFile, storage = store_key, **options) : Shrine::UploadedFile
        # shrine_class.upload(io, storage, **context, **options)
        shrine_class.upload(io, storage, **options)
      end

      # If a new file was attached, deletes previously attached file if any.
      #
      #     previous_file = attacher.file
      #     attacher.attach(file)
      #     attacher.destroy_previous
      #     previous_file.exists? #=> false
      def destroy_previous
        @previous.not_nil!.destroy_attached if changed?
      end

      # Destroys the attached file if it exists and is uploaded to permanent
      # storage.
      #
      #     attacher.file.exists? #=> true
      #     attacher.destroy_attached
      #     attacher.file.exists? #=> false
      def destroy_attached
        destroy if destroy?
      end

      # Destroys the attachment.
      #
      #     attacher.file.exists? #=> true
      #     attacher.destroy
      #     attacher.file.exists? #=> false
      def destroy
        file.try &.delete
      end

      # Returns attached file or raises an exception if no file is attached.
      def file!
        file || raise Error.new("no file is attached")
      end

      # Loads the uploaded file from data generated by `Attacher#data`.
      #
      #     attacher.file #=> nil
      #     attacher.load_data({ "id" => "...", "storage" => "...", "metadata" => { ... } })
      #     attacher.file #=> #<Shrine::UploadedFile>
      def load_data(data : Hash(String, String | UploadedFile::MetadataType))
        @file = uploaded_file(data)
      end

      def load_data(**data)
        @file = uploaded_file(data.to_h.transform_keys { |key| key.to_s })
      end

      def load_data(data : Nil)
        @file = nil
      end

      # Sets the uploaded file with dirty tracking, and runs validations.
      #
      #     attacher.change(uploaded_file)
      #     attacher.file #=> #<Shrine::UploadedFile>
      #     attacher.changed? #=> true
      def change(file : Shrine::UploadedFile?) : Shrine::UploadedFile?
        @previous = dup unless @file == file

        set(file)
      end

      # Sets the uploaded file.
      #
      #     attacher.set(uploaded_file)
      #     attacher.file #=> #<Shrine::UploadedFile>
      #     attacher.changed? #=> false
      def set(file : Shrine::UploadedFile?) : Shrine::UploadedFile?
        @file = file
      end

      # Returns the attached file.
      #
      #     # when a file is attached
      #     attacher.get #=> #<Shrine::UploadedFile>
      #
      #     # when no file is attached
      #     attacher.get #=> nil
      def get
        file
      end

      # If a file is attached, returns the uploaded file URL, otherwise returns
      # nil. Any options are forwarded to the storage.
      #
      #     attacher.file = file
      #     attacher.url #=> "https://..."
      #
      #     attacher.file = nil
      #     attacher.url #=> nil
      def url(**options)
        file.try &.url(**options)
      end

      # Returns whether the attachment has changed.
      #
      #     attacher.changed? #=> false
      #     attacher.attach(file)
      #     attacher.changed? #=> true
      #
      # TODO: This will work incorrect if `@previous` is nil
      def changed?
        !!@previous
      end

      # Returns whether a file is attached.
      #
      #     attacher.attach(io)
      #     attacher.attached? #=> true
      #
      #     attacher.attach(nil)
      #     attacher.attached? #=> false
      def attached?
        !!file
      end

      # Returns whether the file is uploaded to temporary storage.
      #
      #     attacher.cached?       # checks current file
      #     attacher.cached?(file) # checks given file
      def cached?(file = self.file)
        uploaded?(file, cache_key)
      end

      # Returns whether the file is uploaded to permanent storage.
      #
      #     attacher.stored?       # checks current file
      #     attacher.stored?(file) # checks given file
      def stored?(file = self.file)
        uploaded?(file, store_key)
      end

      # Generates serializable data for the attachment.
      #
      #     attacher.data #=> { "id" => "...", "storage" => "...", "metadata": { ... } }
      def data
        file.try &.data
      end

      # Converts JSON or Hash data into a Shrine::UploadedFile object.
      #
      #     attacher.uploaded_file("{\"id\":\"...\",\"storage\":\"...\",\"metadata\":{...}}")
      #     #=> #<Shrine::UploadedFile ...>
      #
      #     attacher.uploaded_file({ "id" => "...", "storage" => "...", "metadata" => {} })
      #     #=> #<Shrine::UploadedFile ...>
      def uploaded_file(value)
        shrine_class.uploaded_file(value)
      end

      # Returns the Shrine class that this attacher's class is namespaced
      # under.
      def shrine_class
        self.class.shrine_class
      end

      # Converts a String or Hash value into an UploadedFile object and ensures
      # it's uploaded to temporary storage.
      #
      #     # from JSON data
      #     attacher.cached("{\"id\":\"...\",\"storage\":\"cache\",\"metadata\":{...}}")
      #     #=> #<Shrine::UploadedFile>
      #
      #     # from Hash data
      #     attacher.cached({ "id" => "...", "storage" => "cache", "metadata" => { ... } })
      #     #=> #<Shrine::UploadedFile>
      private def cached(value : String | Hash(String, String | UploadedFile::MetadataType), **options)
        uploaded_file = uploaded_file(value)

        # reject files not uploaded to temporary storage, because otherwise
        # attackers could hijack other users' attachments
        unless cached?(uploaded_file)
          raise Shrine::NotCached.new "expected cached file, got #{uploaded_file.inspect}"
        end

        uploaded_file
      end

      # Whether attached file should be uploaded to permanent storage.
      private def promote?
        changed? && cached?
      end

      # Whether attached file should be deleted.
      private def destroy?
        attached? && !cached?
      end

      # Returns whether the file is uploaded to specified storage.
      private def uploaded?(file, storage_key)
        file.try &.storage_key == storage_key
      end
    end

    extend ClassMethods
    include InstanceMethods
  end
end
