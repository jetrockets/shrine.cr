require "../../spec_helper"

describe Shrine::Storage::Memory do
  it "uploads, reads, checks existence, and deletes" do
    storage = Shrine::Storage::Memory.new

    storage.upload(IO::Memory.new("data"), "id")
    storage.exists?("id").should be_true

    io = storage.open("id")
    io.gets_to_end.should eq "data"

    storage.url("id").should eq "memory://id"

    storage.delete("id")
    storage.exists?("id").should be_false
  end

  it "raises FileNotFound when opening missing id" do
    storage = Shrine::Storage::Memory.new

    expect_raises(Shrine::FileNotFound) do
      storage.open("missing")
    end
  end

  it "delete_prefixed and clear! work" do
    storage = Shrine::Storage::Memory.new

    storage.upload(IO::Memory.new("a"), "foo/a")
    storage.upload(IO::Memory.new("b"), "foo/b")
    storage.upload(IO::Memory.new("c"), "bar/c")

    storage.delete_prefixed("foo")
    storage.exists?("foo/a").should be_false
    storage.exists?("foo/b").should be_false
    storage.exists?("bar/c").should be_true

    storage.clear!
    storage.exists?("bar/c").should be_false
  end
end
