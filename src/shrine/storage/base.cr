# require "../shrine"

class Shrine
  module Storage
    abstract class Base
      protected def clean(path)
        raise NotImplementedError.new(:clean)
      end
    end
  end
end