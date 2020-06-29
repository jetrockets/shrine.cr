require "../../spec_helper"
require "../../../src/shrine/plugins/add_metadata"

class ShrineWithAddMetadata < Shrine
  load_plugin Shrine::Plugins::AddMetadata

  # redefine Shrine#extract_metadata to make it public
  def extract_metadata(io : IO, **options) : Shrine::UploadedFile::MetadataType
    super
  end

  add_metadata :custom, ->{
    "value"
  }

  add_metadata :multiple_values, ->{
    text = io.gets_to_end

    Shrine::UploadedFile::MetadataType{
      "custom_1" => text,
      "custom_2" => text * 2,
    }
  }

  finalize_plugins!
end

Spectator.describe Shrine::Plugins::AddMetadata do
  include FileHelpers

  let(:uploader) {
    ShrineWithAddMetadata.new("store")
  }

  describe "Shrine.add_metadata" do
    describe "with argument" do
      it "adds declared metadata" do
        metadata = uploader.extract_metadata(fakeio)

        expect(metadata["custom"]).to eq("value")
        expect(metadata["size"]).to be_a(Int32)
      end

      it "adds the metadata method to UploadedFile" do
        uploaded_file = uploader.upload(fakeio)

        expect(uploaded_file.metadata["custom"]).to eq("value")
      end
    end

    describe "withщге argument" do
      it "adds declared metadata" do
        metadata = uploader.extract_metadata(fakeio)

        expect(metadata["custom_1"]).to eq(fakeio.gets_to_end)
        expect(metadata["custom_2"]).to eq(fakeio.gets_to_end * 2)
        expect(metadata["size"]).to be_a(Int32)
      end

      it "adds the metadata method to UploadedFile" do
        uploaded_file = uploader.upload(fakeio)

        expect(uploaded_file.metadata["custom_1"]).to eq(fakeio.gets_to_end)
        expect(uploaded_file.metadata["custom_2"]).to eq(fakeio.gets_to_end * 2)
      end
    end
  end
end
