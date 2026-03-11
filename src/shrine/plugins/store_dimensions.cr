require "fastimage"

module Shrine
  module StoreDimensions
    def self.extract(io)
      if dims = FastImage.dimensions(io)
        {width: dims[0], height: dims[1]}
      else
        {width: nil, height: nil}
      end
    end
  end

  class UploadedFile
    def width
      metadata["width"]?
    end

    def height
      metadata["height"]?
    end

    def dimensions
      {width, height} if width && height
    end
  end
end