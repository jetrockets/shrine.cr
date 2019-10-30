require "./base"

class Shrine
  module Storage
    class FileSystem < Storage::Base
      getter directory : String
      getter prefix : String?
      getter? clean
      getter permissions
      getter directory_permissions

      DEFAULT_PERMISSIONS           = 0o644
      DEFAULT_DIRECTORY_PERMISSIONS = 0o755

      def initialize(directory : String, prefix : String? = nil, @clean = true, @permissions : Int = DEFAULT_PERMISSIONS, @directory_permissions : Int = DEFAULT_DIRECTORY_PERMISSIONS)
        if prefix
          @prefix = relative(prefix)
          @directory = File.expand_path(File.join(directory, @prefix.not_nil!))
        else
          @directory = File.expand_path(directory)
        end

        unless Dir.exists?(@directory)
          Dir.mkdir_p(@directory, mode: directory_permissions)
        end
      end

      # Copies the file into the given location.
      def upload(io, id : String, move = false, **options)
        if move && movable?(io)
          move(io, path!(id))
        else
          File.write(path!(id), content: io, perm: permissions)
          # IO.copy(io, path!(id))
        end
      end

      # Opens the file on the given location in read mode. Accepts additional
      # `File.open` arguments.
      def open(id, **options) : File
        # TODO pass other options
        File.open(path(id), mode: "rb")
      rescue Errno
        raise Shrine::FileNotFound.new "file #{id.inspect} not found on storage"
      end

      # Returns true if the file exists on the filesystem.
      def exists?(id) : Bool
        File.exists?(path(id))
      end

      # Returns the full path to the file.
      def path(id)
        File.join(directory, id.gsub("/", File::SEPARATOR))
      end

      # If #prefix is not present, returns a path composed of #directory and
      # the given `id`. If #prefix is present, it excludes the #directory part
      # from the returned path (e.g. #directory can be set to "public" folder).
      # Both cases accept a `:host` value which will be prefixed to the
      # generated path.
      def url(id, host : String? = nil, **options)
        path = (prefix ? relative_path(id) : path(id)).to_s
        host ? host + path : path
      end

      # Cleans all empty subdirectories up the hierarchy.
      protected def clean(path)
        Path[path].each_parent do |pathname|
          if Dir.empty?(pathname.to_s) && pathname != directory
            Dir.rmdir(pathname.to_s)
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
        Path["/"] / prefix.not_nil! / id.gsub("/", File::SEPARATOR)
      end

      private def relative(path)
        path.sub(%r{^/}, "")
      end
    end
  end
end
