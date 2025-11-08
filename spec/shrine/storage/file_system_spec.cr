require "../../spec_helper"
require "file_utils"

def build_fs_storage(root, prefix = nil, permissions = Shrine::Storage::FileSystem::DEFAULT_PERMISSIONS, dir_permissions = Shrine::Storage::FileSystem::DEFAULT_DIRECTORY_PERMISSIONS)
  Shrine::Storage::FileSystem.new(directory: root, prefix: prefix, permissions: permissions, directory_permissions: dir_permissions)
end

describe Shrine::Storage::FileSystem do
  describe "#initialize" do
    it "expands the directory and creates it without prefix" do
      root = File.join(Dir.tempdir, "shrine-init")
      storage = build_fs_storage(root)

      File.directory?(storage.expanded_directory).should be_true
      storage.expanded_directory.should eq File.expand_path(root)

      FileUtils.rm_rf(root)
    end

    it "expands the directory and creates it with prefix" do
      root = File.join(Dir.tempdir, "shrine-init-prefix")
      prefix = "prefix"
      storage = build_fs_storage(root, prefix)

      File.directory?(storage.expanded_directory).should be_true
      storage.expanded_directory.should eq File.expand_path(File.join(root, prefix))

      FileUtils.rm_rf(root)
    end

    it "sets custom directory permissions" do
      root = File.join(Dir.tempdir, "shrine-perm")
      dir_permissions = 0o500
      storage = build_fs_storage(root, nil, Shrine::Storage::FileSystem::DEFAULT_PERMISSIONS, dir_permissions)

      File.info(storage.expanded_directory).permissions.value.should eq dir_permissions

      FileUtils.rm_rf(root)
    end
  end

  describe "#upload" do
    it "creates subdirectories and copies content" do
      root = File.join(Dir.tempdir, "shrine-upload")
      storage = build_fs_storage(root)

      storage.upload(FakeIO.new("A" * 20_000), "a/b/c/foo.jpg")

      storage.exists?("a/b/c/foo.jpg").should be_true
      storage.open("a/b/c/foo.jpg").size.should eq 20_000

      FileUtils.rm_rf(root)
    end

    it "respects file permissions" do
      root = File.join(Dir.tempdir, "shrine-upload-perm")
      storage = build_fs_storage(root, nil, 0o600)

      storage.upload(FakeIO.new, "foo.jpg")
      File.info(storage.open("foo.jpg").path).permissions.value.should eq 0o600

      FileUtils.rm_rf(root)
    end

    it "sets directory permissions on intermediary directories" do
      root = File.join(Dir.tempdir, "shrine-upload-dir-perm")
      storage = build_fs_storage(root, nil, Shrine::Storage::FileSystem::DEFAULT_PERMISSIONS, 0o744)

      storage.upload(FakeIO.new, "a/b/c/file.jpg")

      File.info("#{storage.expanded_directory}/a").permissions.value.should eq 0o744
      File.info("#{storage.expanded_directory}/a/b").permissions.value.should eq 0o744
      File.info("#{storage.expanded_directory}/a/b/c").permissions.value.should eq 0o744

      FileUtils.rm_rf(root)
    end

    it "moves files when move: true" do
      root = File.join(Dir.tempdir, "shrine-move")
      storage = build_fs_storage(root)
      file = tempfile("file")

      storage.upload(file, "foo", move: true)

      storage.open("foo").gets_to_end.should eq "file"
      File.exists?(file.path).should be_false

      FileUtils.rm_rf(root)
    end
  end

  describe "#url" do
    it "returns full path without prefix" do
      root = File.join(Dir.tempdir, "shrine-url")
      storage = build_fs_storage(root)
      storage.upload(FakeIO.new, "foo.jpg")

      storage.url("foo.jpg").should eq "#{storage.expanded_directory}/foo.jpg"

      FileUtils.rm_rf(root)
    end

    it "applies host without prefix" do
      root = File.join(Dir.tempdir, "shrine-url-host")
      storage = build_fs_storage(root)
      storage.upload(FakeIO.new, "foo.jpg")

      storage.url("foo.jpg", host: "http://example.test").should eq "http://example.test#{root}/foo.jpg"

      FileUtils.rm_rf(root)
    end

    it "returns path relative to prefix" do
      root = File.join(Dir.tempdir, "shrine-url-prefix")
      prefix = "prefix"
      storage = build_fs_storage(root, prefix)
      storage.upload(FakeIO.new, "foo.jpg")

      storage.url("foo.jpg").should eq "/#{prefix}/foo.jpg"

      FileUtils.rm_rf(root)
    end

    it "accepts host with prefix" do
      root = File.join(Dir.tempdir, "shrine-url-prefix-host")
      prefix = "prefix"
      storage = build_fs_storage(root, prefix)
      storage.upload(FakeIO.new, "foo.jpg")

      storage.url("foo.jpg", host: "http://cdn.test").should eq "http://cdn.test/#{prefix}/foo.jpg"

      FileUtils.rm_rf(root)
    end
  end

  describe "#delete" do
    it "deletes file and cleans empty directories" do
      root = File.join(Dir.tempdir, "shrine-delete-clean")
      storage = build_fs_storage(root)

      storage.upload(FakeIO.new("data"), "a/b/c/file.txt")
      File.exists?(storage.path("a/b/c/file.txt")).should be_true

      storage.delete("a/b/c/file.txt")
      File.exists?(storage.path("a/b/c/file.txt")).should be_false

      FileUtils.rm_rf(root)
    end

    it "raises FileNotFound on missing file open" do
      root = File.join(Dir.tempdir, "shrine-open-missing")
      storage = build_fs_storage(root)

      expect_raises(Shrine::FileNotFound) do
        storage.open("nonexistent.txt")
      end

      FileUtils.rm_rf(root)
    end

    it "accepts File.open options" do
      root = File.join(Dir.tempdir, "shrine-open-options")
      storage = build_fs_storage(root)

      # Upload a test file
      storage.upload(IO::Memory.new("test content"), "test.txt")

      # Test with custom mode (read-only text mode)
      file = storage.open("test.txt", mode: "r")
      file.should be_a(File)
      file.close

      # Test with default binary mode
      file = storage.open("test.txt")
      file.should be_a(File)
      file.close

      # Test with encoding parameter
      file = storage.open("test.txt", mode: "r", encoding: "utf-8")
      file.should be_a(File)
      file.close

      FileUtils.rm_rf(root)
    end
  end

  describe "#path" do
    it "returns path to the file" do
      root = File.join(Dir.tempdir, "shrine-path")
      storage = build_fs_storage(root)

      storage.path("foo/bar/baz").should eq "#{root}/foo/bar/baz"

      FileUtils.rm_rf(root)
    end
  end
end
