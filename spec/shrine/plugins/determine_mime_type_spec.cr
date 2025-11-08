require "../../spec_helper"
require "../../../src/shrine/plugins/determine_mime_type"

class ShrineWithDetermineMimeTypeFile < Shrine
  load_plugin(Shrine::Plugins::DetermineMimeType,
    analyzer: Shrine::Plugins::DetermineMimeType::Tools::File)

  finalize_plugins!
end

class ShrineWithDetermineMimeTypeContentType < Shrine
  load_plugin(Shrine::Plugins::DetermineMimeType,
    analyzer: Shrine::Plugins::DetermineMimeType::Tools::ContentType)

  finalize_plugins!
end

class ShrineWithDetermineMimeTypeMime < Shrine
  load_plugin(Shrine::Plugins::DetermineMimeType,
    analyzer: Shrine::Plugins::DetermineMimeType::Tools::Mime)

  finalize_plugins!
end

describe Shrine::Plugins::DetermineMimeType do
  it "exposes Tools enum" do
    Shrine::Plugins::DetermineMimeType::Tools.values.size.should be > 0
  end

  it "provides MimeTypeAnalyzer for each tool" do
    Shrine::Plugins::DetermineMimeType::MimeTypeAnalyzer.new(
      Shrine::Plugins::DetermineMimeType::Tools::File
    ).should_not be_nil

    Shrine::Plugins::DetermineMimeType::MimeTypeAnalyzer.new(
      Shrine::Plugins::DetermineMimeType::Tools::Mime
    ).should_not be_nil

    Shrine::Plugins::DetermineMimeType::MimeTypeAnalyzer.new(
      Shrine::Plugins::DetermineMimeType::Tools::ContentType
    ).should_not be_nil
  end

  it "adds determine_mime_type to uploader" do
    ShrineWithDetermineMimeTypeFile.responds_to?(:determine_mime_type).should be_true
  end

  describe "file analyzer" do
    it "determines MIME type from file contents" do
      ShrineWithDetermineMimeTypeFile.determine_mime_type(image).should eq "image/png"
    end

    it "returns text/plain for unidentified MIME types" do
      ShrineWithDetermineMimeTypeFile.determine_mime_type(fakeio("a" * 1024)).should eq "text/plain"
    end

    it "is able to determine MIME type for non-files" do
      io = fakeio(image.gets_to_end)
      ShrineWithDetermineMimeTypeFile.determine_mime_type(io).should eq "image/png"
    end

    it "returns nil for empty IOs" do
      ShrineWithDetermineMimeTypeFile.determine_mime_type(fakeio("")).should be_nil
    end
  end

  describe "mime analyzer" do
    it "extracts MIME type from the file extension" do
      ShrineWithDetermineMimeTypeMime.determine_mime_type(fakeio(filename: "image.png")).should eq "image/png"
      ShrineWithDetermineMimeTypeMime.determine_mime_type(image).should eq "image/png"
    end

    it "extracts MIME type from file extension when IO is empty" do
      ShrineWithDetermineMimeTypeMime.determine_mime_type(fakeio("", filename: "image.png")).should eq "image/png"
    end

    it "returns nil on unknown extension" do
      ShrineWithDetermineMimeTypeMime.determine_mime_type(fakeio(filename: "image.foo")).should be_nil
    end

    it "returns nil when input is not a file" do
      ShrineWithDetermineMimeTypeMime.determine_mime_type(fakeio).should be_nil
    end
  end
end
