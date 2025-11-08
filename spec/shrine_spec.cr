require "./spec_helper"

describe Shrine do
  describe ".find_storage" do
    it "returns registered storage" do
      Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
      Shrine.find_storage("store").should be_a(Shrine::Storage::Base)
    end
  end

  describe ".warn" do
    it "logs a warning without raising" do
      # We can't easily assert logger output here; just ensure it doesn't raise.
      Shrine.warn("test warning")
    end
  end

  it "raises when storage is missing" do
    Shrine.settings.storages.delete("missing") if Shrine.settings.storages["missing"]?
    expect_raises(Shrine::Error) { Shrine.find_storage("missing") }
  end

  describe ".upload/.cache/.store" do
    it "upload delegates to instance and stores in given storage" do
      Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
      file = Shrine.upload(IO::Memory.new("data"), "store")
      file.should be_a(Shrine::UploadedFile)
      file.storage_key.should eq "store"
    end

    it "cache uploads to cache storage" do
      Shrine.settings.storages["cache"] = Shrine::Storage::Memory.new
      file = Shrine.cache(IO::Memory.new("cache"))
      file.storage_key.should eq "cache"
    end

    it "store uploads to store storage" do
      Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
      file = Shrine.store(IO::Memory.new("store"))
      file.storage_key.should eq "store"
    end
  end

  describe ".uploaded_file" do
    it "builds from hash" do
      data = {"id" => "123", "storage_key" => "store", "metadata" => Shrine::UploadedFile::MetadataType{"foo" => "bar"}}
      json = data.to_json
      file = Shrine.uploaded_file(json)
      file.id.should eq "123"
      file.storage_key.should eq "store"
      file.metadata["foo"].should eq "bar"
    end

    it "returns same object when UploadedFile given" do
      Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
      original = Shrine.store(IO::Memory.new("data"))
      Shrine.uploaded_file(original).should be(original)
    end
  end

  describe ".with_file" do
    it "yields existing File without closing it" do
      file = File.tempfile("shrine-with-file") do |_file|
        f.puts "test"
      end
      file = File.open(file.path)

      Shrine.with_file(file) do |_file|
        f.should be_a(File)
        f.path.should eq(file.path)
        f.closed?.should be_false
      end

      file.closed?.should be_false
      file.close
    end

    it "downloads Shrine::UploadedFile to a tempfile" do
      uploader = Shrine.new("cache")
      io = IO::Memory.new("content")
      uploaded = uploader.upload(io)

      Shrine.with_file(uploaded) do |file|
        file.should be_a(File)
        File.read(file.path).should eq("content")
      end
    end

    it "wraps IO into tempfile" do
      io = IO::Memory.new("content")

      Shrine.with_file(io) do |file|
        file.should be_a(File)
        File.read(file.path).should eq("content")
      end

      io.pos.should eq(0)
    end
  end
end
