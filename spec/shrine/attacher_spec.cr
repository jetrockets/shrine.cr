require "../spec_helper"

describe Shrine::Attacher do
  it "assigns and uploads to cache" do
    attacher = Shrine::Attacher.new
    attacher.attach_cached(IO::Memory.new("data"))

    attacher.file.should be_a(Shrine::UploadedFile)
    attacher.cached?.should be_true
  end

  it "attaches cached from JSON/Hash data" do
    attacher = Shrine::Attacher.new
    Shrine.settings.storages["cache"] = Shrine::Storage::Memory.new
    cached_file = Shrine.cache(IO::Memory.new("data"))

    json = cached_file.data.to_json
    attacher.attach_cached(json)
    attacher.cached?.should be_true

    attacher2 = Shrine::Attacher.new
    attacher2.attach_cached(cached_file.data)
    attacher2.cached?.should be_true
  end

  it "raises NotCached when cached data is not from cache storage" do
    attacher = Shrine::Attacher.new
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    stored = Shrine.store(IO::Memory.new("data"))

    expect_raises(Shrine::NotCached) do
      attacher.attach_cached(stored.data)
    end
  end

  it "attach(nil) clears attachment" do
    attacher = Shrine::Attacher.new
    attacher.attach_cached(IO::Memory.new("data"))
    attacher.file.should_not be_nil

    attacher.attach(nil)
    attacher.file.should be_nil
    attacher.attached?.should be_false
  end

  it "finalize promotes cached and destroys previous" do
    Shrine.settings.storages["cache"] = Shrine::Storage::Memory.new
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new

    attacher = Shrine::Attacher.new
    attacher.attach_cached(IO::Memory.new("v1"))
    attacher.finalize

    first = attacher.file!.dup
    attacher.attach_cached(IO::Memory.new("v2"))
    attacher.finalize

    attacher.stored?.should be_true
    first.exists?.should be_false
  end

  it "destroy_attached only destroys stored files" do
    Shrine.settings.storages["cache"] = Shrine::Storage::Memory.new
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new

    attacher = Shrine::Attacher.new
    attacher.attach_cached(IO::Memory.new("cache"))
    attacher.destroy_attached
    attacher.cached?.should be_true

    attacher.promote
    attacher.destroy_attached
    attacher.file.try(&.exists?).should be_false
  end

  it "file! raises when no file" do
    attacher = Shrine::Attacher.new
    expect_raises(Shrine::Error) { attacher.file! }
  end

  it "url returns nil when no file" do
    attacher = Shrine::Attacher.new
    attacher.url.should be_nil
  end

  it "url forwards options to storage" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    attacher = Shrine::Attacher.new
    attacher.attach(IO::Memory.new("data"))

    url = attacher.url
    url.should_not be_nil
    url.should contain("memory://") if url
  end

  it "cached?/stored? accept explicit file" do
    Shrine.settings.storages["cache"] = Shrine::Storage::Memory.new
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new

    attacher = Shrine::Attacher.new
    cached = Shrine.cache(IO::Memory.new("cache"))
    stored = Shrine.store(IO::Memory.new("store"))

    attacher.cached?(cached).should be_true
    attacher.cached?(stored).should be_false
    attacher.stored?(stored).should be_true
    attacher.stored?(cached).should be_false
  end

  it "serializes and loads data" do
    attacher = Shrine::Attacher.new
    attacher.attach(IO::Memory.new("data"))
    data = attacher.data

    loaded = Shrine::Attacher.from_data(data)
    loaded.file.should_not be_nil
    loaded.file.should_not be_nil
    attacher.file.should_not be_nil
    loaded.file.should_not be_nil
    attacher.file.should_not be_nil
    loaded.file.try(&.id).should eq attacher.file.try(&.id)
  end

  it "changed? tracks attachment changes" do
    attacher = Shrine::Attacher.new

    # Initially, no changes have been made
    attacher.changed?.should be_false

    # After attaching a file, it should be marked as changed
    attacher.attach(IO::Memory.new("data"))
    attacher.changed?.should be_true

    # After finalizing, it should no longer be marked as changed
    attacher.finalize
    attacher.changed?.should be_false

    # Attaching nil should also mark as changed
    attacher.attach(nil)
    attacher.changed?.should be_true
  end
end
