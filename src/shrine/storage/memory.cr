require "./base"

class Shrine
  module Storage
    class Memory < Storage::Base
      getter store

      def initialize
        @store = {} of String => String
      end

      def upload(io : IO | UploadedFile, id : String, move = false, **options)
        store[id.to_s] = io.gets_to_end
      end

      def open(id : String) : IO
        # StringIO.new(store.fetch(id))
        IO::Memory.new(store[id])
      rescue KeyError
        raise Shrine::FileNotFound.new("file #{id.inspect} not found on storage")
      end

      def open(id : String, **options) : IO
        open(id)
      end

      def exists?(id : String) : Bool
        store.has_key?(id)
      end

      def url(id : String, **options) : String
        "memory://#{path(id)}"
      end

      def path(id : String) : String
        id
      end

      def delete(id : String)
        store.delete(id)
      end

      def delete_prefixed(delete_prefix : String)
        delete_prefix = delete_prefix.chomp("/") + "/"
        store.delete_if { |key, _value| key.start_with?(delete_prefix) }
      end

      def clear!
        store.clear
      end

      protected def clean(path)
      end
    end
  end
end
