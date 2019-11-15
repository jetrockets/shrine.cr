# require "../shrine"

class Shrine
  module Storage
    abstract class Base
      def url(id, **options)
        raise NotImplementedError.new(:url)
      end

      protected def clean(path)
        raise NotImplementedError.new(:clean)
      end
    end
  end
end
