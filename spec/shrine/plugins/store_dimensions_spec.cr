require "../../spec_helper"
require "../../../src/shrine/plugins/store_dimensions"

class ShrineWithStoreDimensionsUsingIdentify < Shrine
  load_plugin(Shrine::Plugins::StoreDimensions,
    analyzer: Shrine::Plugins::StoreDimensions::Tools::Identify)

  finalize_plugins!
end

class ShrineWithStoreDimensionsUsingFastImage < Shrine
  load_plugin(Shrine::Plugins::StoreDimensions,
    analyzer: Shrine::Plugins::StoreDimensions::Tools::FastImage)

  # redefine Shrine#extract_metadata to make it public
  def extract_metadata(io : IO, **options) : Shrine::UploadedFile::MetadataType
    super
  end

  finalize_plugins!
end

describe Shrine::Plugins::StoreDimensions do
  describe "primary purpose" do
    it "stores width and height in metadata" do
      uploader = ShrineWithStoreDimensionsUsingFastImage.new("store")
      metadata = uploader.extract_metadata(image("320x180.jpg"))

      metadata["width"].should eq 320
      metadata["height"].should eq 180
    end

    it "adds width/height metadata to uploaded file" do
      uploader = ShrineWithStoreDimensionsUsingFastImage.new("store")
      file = uploader.upload(image)

      file.metadata["width"].should eq 300
      file.metadata["height"].should eq 300
    end
  end

  describe "fastimage analyzer" do
    it "extracts image dimensions" do
      ShrineWithStoreDimensionsUsingFastImage.extract_dimensions(image).should eq({300, 300})
    end

    it "fails with missing image data" do
      expect_raises(Shrine::Error) do
        ShrineWithStoreDimensionsUsingFastImage.extract_dimensions(fakeio)
      end
    end
  end

  describe "identify analyzer" do
    it "extracts image dimensions" do
      ShrineWithStoreDimensionsUsingIdentify.extract_dimensions(image).should eq({300, 300})
    end

    it "fails with missing image data" do
      expect_raises(Shrine::Error) do
        ShrineWithStoreDimensionsUsingIdentify.extract_dimensions(fakeio)
      end
    end
  end
end
