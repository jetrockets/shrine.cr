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

Spectator.describe Shrine::Plugins::StoreDimensions do
  include FileHelpers

  describe "primary purpose" do
    let(uploader) {
      ShrineWithStoreDimensionsUsingFastImage.new("store")
    }

    it "stores width and height in metadata" do
      metadata = uploader.extract_metadata(image("320x180.jpg"))

      expect(metadata["width"]).to eq(320)
      expect(metadata["height"]).to eq(180)
    end
  end

  describe "fastimage in analyzer" do
    subject { ShrineWithStoreDimensionsUsingFastImage }

    it "extracts image dimensions" do
      expect(subject.extract_dimensions(image)).to eq({300, 300})
    end

    it "fails with missing image data" do
      expect_raises(Shrine::Error) do
        subject.extract_dimensions(fakeio)
      end
    end
  end

  describe "identify analyzer" do
    subject { ShrineWithStoreDimensionsUsingIdentify }

    it "extracts image dimensions" do
      expect(subject.extract_dimensions(image)).to eq({300, 300})
    end

    it "fails with missing image data" do
      expect_raises(Shrine::Error) do
        subject.extract_dimensions(fakeio)
      end
    end
  end
end
