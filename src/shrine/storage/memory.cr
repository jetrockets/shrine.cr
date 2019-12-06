require "./base"

class Shrine
  module Storage
    class Memory < Storage::Base
      getter store

      def initialize
        @store = {} of String => String
      end

      def upload(io, id, **options)
        store[id.to_s] = io.gets_to_end
      end

      def open(id)
        # StringIO.new(store.fetch(id))
        IO::Memory.new(store[id])
      rescue KeyError
        raise Shrine::FileNotFound.new("file #{id.inspect} not found on storage")
      end

      def exists?(id)
        store.has_key?(id)
      end

      def url(id, **options)
        "memory://#{path(id)}"
      end

      def path(id)
        id
      end

      def delete(id)
        store.delete(id)
      end

      def delete_prefixed(delete_prefix)
        delete_prefix = delete_prefix.chomp("/") + "/"
        store.delete_if { |key, _value| key.start_with?(delete_prefix) }
      end

      def clear!
        store.clear
      end

      private def clean(path)
      end
    end
  end
end
