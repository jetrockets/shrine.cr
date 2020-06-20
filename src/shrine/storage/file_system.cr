require "./base"

class Shrine
  module Storage
    class FileSystem < Storage::Base
      getter directory : String
      getter prefix : String?
      getter permissions
      getter directory_permissions

      DEFAULT_PERMISSIONS           = 0o644
      DEFAULT_DIRECTORY_PERMISSIONS = 0o755

      def expanded_directory : String
        if relative_prefix
          File.expand_path(File.join(directory, relative_prefix.not_nil!))
        else
          File.expand_path(directory)
        end
      end

      # Initializes a storage for uploading to the filesystem.
      #
      # :prefix
      # :  The directory relative to `directory` to which files will be stored,
      #    and it is included in the URL.
      #
      # :permissions
      # :  The UNIX permissions applied to created files. Can be set to `nil`,
      #    in which case the default permissions will be applied. Defaults to
      #    `0644`.
      #
      # :directory_permissions
      # :  The UNIX permissions applied to created directories. Can be set to
      #    `nil`, in which case the default permissions will be applied. Defaults
      #    to `0755`.
      #
      # :clean
      # :  By default empty folders inside the directory are automatically
      #    deleted, but if it happens that it causes too much load on the
      #    filesystem, you can set this option to `false`.
      def initialize(@directory : String, @prefix : String? = nil, @clean = true, @permissions : Int = DEFAULT_PERMISSIONS, @directory_permissions : Int = DEFAULT_DIRECTORY_PERMISSIONS)
        unless Dir.exists?(expanded_directory)
          Dir.mkdir_p(expanded_directory, mode: directory_permissions)
        end
      end

      # Copies the file into the given location.
      def upload(io : IO | UploadedFile, id : String, move = false, **options)
        if move && movable?(io)
          move(io, path!(id))
        else
          File.write(path!(id), content: io, perm: permissions)
        end
      end

      # Opens the file on the given location in read mode. Accepts additional
      # `File.open` arguments.
      def open(id : String, **options) : File
        # TODO pass other options
        File.open(path(id), mode: "rb")
      rescue RuntimeError
        raise Shrine::FileNotFound.new "file #{id.inspect} not found on storage"
      end

      # Returns true if the file exists on the filesystem.
      def exists?(id : String) : Bool
        File.exists?(path(id))
      end

      # Returns the full path to the file.
      def path(id : String) : String
        File.join(expanded_directory, id.gsub("/", File::SEPARATOR))
      end

      # If #relative_prefix is not present, returns a path composed of #directory and
      # the given `id`. If #relative_prefix is present, it excludes the #directory part
      # from the returned path (e.g. #directory can be set to "public" folder).
      # Both cases accept a `:host` value which will be prefixed to the
      # generated path.
      # def url(id, host : String? = nil, **options)
      def url(id : String, host : String? = nil, **options) : String
        path = (relative_prefix ? relative_path(id) : path(id)).to_s
        host ? host + path : path
      end

      # Deletes the file, and by default deletes the containing directory if
      # it's empty.
      def delete(id : String)
        path = path(id)
        File.delete(path)
        clean(path) if clean?
      end

      # Cleans all empty subdirectories up the hierarchy.
      protected def clean(path)
        Path[path].each_parent do |pathname|
          if Dir.empty?(pathname.to_s) && pathname != directory
            Dir.delete(pathname.to_s)
          else
            break
          end
        end
      end

      # Moves the file to the given location.
      private def move(io : IO, path)
        if io.responds_to?(:path)
          File.rename io.path, path
        end
      end

      private def move(io : UploadedFile, path)
        File.rename io.storage.path(io.id), path
        io.storage.clean(io.storage.path(io.id)) if io.storage.clean?
      end

      # Returns true if the file is a `File` or a UploadedFile uploaded by the
      # FileSystem storage.
      private def movable?(io)
        io.responds_to?(:path) ||
          (io.is_a?(UploadedFile) && io.storage.is_a?(Storage::FileSystem))
      end

      # Creates all intermediate directories for that location.
      private def path!(id : String)
        path = path(id)
        Dir.mkdir_p(Path[path].dirname, mode: directory_permissions)
        path
      end

      private def relative_path(id : String)
        Path["/"] / relative_prefix.not_nil! / id.gsub("/", File::SEPARATOR)
      end

      private def relative(path)
        path.sub(%r{^/}, "")
      end

      private def relative_prefix : String?
        relative(prefix.not_nil!) if prefix
      end
    end
  end
end
