require "../../spec_helper"
require "../../../src/shrine/plugins/determine_mime_type"

class ShrineWithDetermineMimeTypeFile < Shrine
  load_plugin(Shrine::Plugins::DetermineMimeType,
    analyzer: Shrine::Plugins::DetermineMimeType::Tools::File)

  finalize_plugins!
end

class ShrineWithDetermineMimeTypeMime < Shrine
  load_plugin(Shrine::Plugins::DetermineMimeType,
    analyzer: Shrine::Plugins::DetermineMimeType::Tools::Mime)

  finalize_plugins!
end

Spectator.describe Shrine::Plugins::DetermineMimeType do
  include FileHelpers

  context "file analyzer" do
    subject { ShrineWithDetermineMimeTypeFile }

    describe ".determine_mime_type" do
      it "determines MIME type from file contents" do
        expect(subject.determine_mime_type(image)).to eq("image/png")
      end

      it "returns text/plain for unidentified MIME types" do
        expect(subject.determine_mime_type(fakeio("a" * 1024))).to eq("text/plain")
      end

      it "is able to determine MIME type for non-files" do
        expect(subject.determine_mime_type(fakeio(image.gets_to_end))).to eq("image/png")
      end

      it "returns nil for empty IOs" do
        expect(subject.determine_mime_type(fakeio(""))).to be_nil
      end
    end
  end

  context "mime analyzer" do
    subject { ShrineWithDetermineMimeTypeMime }

    describe ".determine_mime_type" do
      it "extract MIME type from the file extension" do
        expect(subject.determine_mime_type(fakeio(filename: "image.png"))).to eq("image/png")
        expect(subject.determine_mime_type(image)).to eq("image/png")
      end

      it "extracts MIME type from file extension when IO is empty" do
        expect(subject.determine_mime_type(fakeio("", filename: "image.png"))).to eq("image/png")
      end

      it "returns nil on unknown extension" do
        expect(subject.determine_mime_type(fakeio(filename: "image.foo"))).to be_nil
      end

      it "returns nil when input is not a file" do
        expect(subject.determine_mime_type(fakeio)).to be_nil
      end
    end
  end
end
