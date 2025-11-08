require "../spec_helper"

describe Shrine::UploadedFile do
  it "roundtrips via JSON" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    original = Shrine.store(fakeio("data"))

    json = original.to_json
    loaded = Shrine::UploadedFile.from_json(json)

    loaded.id.should eq original.id
    loaded.storage_key.should eq original.storage_key
    loaded.metadata.should eq original.metadata
  end

  it "supports [] access to metadata" do
    file = Shrine::UploadedFile.new("id", "cache", Shrine::UploadedFile::MetadataType{"foo" => "bar"})
    file["foo"].should eq "bar"
  end

  it "#open yields IO with block and returns IO without block" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    file = Shrine.store(fakeio("data"))

    file.open do |io|
      io.gets_to_end.should eq "data"
    end

    io = file.open
    io.gets_to_end.should eq "data"
    io.close
  end

  it "#download with block cleans up tempfile" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    file = Shrine.store(fakeio("data"))

    path = nil
    file.download do |tempfile|
      path = tempfile.path
      File.read(path).should eq "data"
    end

    path.should_not be_nil
    File.exists?(path).should be_false
  end

  it "#replace uploads new content to same id" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    file = Shrine.store(fakeio("old"))

    file.replace(fakeio("new"))

    Shrine.settings.storages["store"].open(file.id).gets_to_end.should eq "new"
  end

  it "compares equality by class, id, and storage" do
    a = Shrine::UploadedFile.new("id", "store")
    b = Shrine::UploadedFile.new("id", "store")
    c = Shrine::UploadedFile.new("id2", "store")

    (a == b).should be_true
    (a == c).should be_false
  end

  it "exposes #data hash" do
    metadata = Shrine::UploadedFile::MetadataType{"foo" => "bar"}
    file = Shrine::UploadedFile.new("id", "store", metadata)

    data = file.data
    data["id"].should eq "id"
    data["storage_key"].should eq "store"
    data["metadata"].should eq metadata
  end
  it "initializes metadata if absent" do
    file = Shrine::UploadedFile.new("id", "cache")
    file.metadata.should be_a(Shrine::UploadedFile::MetadataType)
  end

  describe "#original_filename" do
    it "returns nil when missing" do
      file = Shrine::UploadedFile.new("id", "cache")
      file.original_filename.should be_nil
    end

    it "returns from metadata when present" do
      metadata = Shrine::UploadedFile::MetadataType{"filename" => "foo.jpg"}
      file = Shrine::UploadedFile.new("id", "cache", metadata)
      file.original_filename.should eq "foo.jpg"
    end
  end

  describe "#extension" do
    it "uses id extension when present" do
      file = Shrine::UploadedFile.new("foo.jpg", "cache")
      file.extension.should eq "jpg"
    end

    it "is nil without extension" do
      file = Shrine::UploadedFile.new("foo", "cache")
      file.extension.should be_nil
    end

    it "uses filename from metadata" do
      metadata = Shrine::UploadedFile::MetadataType{"filename" => "foo.jpg"}
      file = Shrine::UploadedFile.new("id", "cache", metadata)
      file.extension.should eq "jpg"
    end
  end

  describe "#size" do
    it "returns nil when missing" do
      file = Shrine::UploadedFile.new("id", "cache")
      file.size.should be_nil
    end

    it "returns integer size" do
      metadata = Shrine::UploadedFile::MetadataType{"size" => 50}
      file = Shrine::UploadedFile.new("id", "cache", metadata)
      file.size.should eq 50
    end

    it "parses string size" do
      metadata = Shrine::UploadedFile::MetadataType{"size" => "50"}
      file = Shrine::UploadedFile.new("id", "cache", metadata)
      file.size.should eq 50
    end
  end

  describe "#mime_type/#content_type" do
    it "returns mime_type from metadata" do
      metadata = Shrine::UploadedFile::MetadataType{"mime_type" => "image/jpeg"}
      file = Shrine::UploadedFile.new("id", "cache", metadata)

      file.mime_type.should eq "image/jpeg"
      file.content_type.should eq "image/jpeg"
    end

    it "returns nil when missing" do
      file = Shrine::UploadedFile.new("id", "cache")
      file.mime_type.should be_nil
      file.content_type.should be_nil
    end
  end

  it "closes underlying IO on #close" do
    uploader = Shrine.new("store")
    file = uploader.upload(fakeio)
    io = file.io
    file.close
    io.closed?.should be_true
  end

  it "delegates #url/#exists?/#delete to storage" do
    storage = Shrine::Storage::Memory.new
    Shrine.settings.storages["store"] = storage
    storage.upload(fakeio("data"), "id")

    file = Shrine::UploadedFile.new("id", "store")
    file.url.should eq "memory://id"
    file.exists?.should be_true

    file.delete
    file.exists?.should be_false
  end

  it "streams and downloads" do
    storage = Shrine::Storage::Memory.new
    Shrine.settings.storages["store"] = storage
    storage.upload(fakeio("data"), "id")
    file = Shrine::UploadedFile.new("id", "store")

    io = IO::Memory.new
    file.stream(io)
    io.to_s.should eq "data"

    tempfile = file.download
    File.read(tempfile.path).should eq "data"
    tempfile.close
    tempfile.delete
  end
end
