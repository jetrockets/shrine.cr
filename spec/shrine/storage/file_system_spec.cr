require "file_utils"

require "../../spec_helper"

Spectator.describe Shrine::Storage::FileSystem do
  include FileHelpers

  subject {
    Shrine::Storage::FileSystem.new(
      directory: root,
      prefix: prefix,
      permissions: permissions,
      directory_permissions: directory_permissions
    )
  }

  let(root) { File.join(Dir.tempdir, "shrine") }
  let(prefix) { nil }
  let(permissions) { Shrine::Storage::FileSystem::DEFAULT_PERMISSIONS }
  let(directory_permissions) { Shrine::Storage::FileSystem::DEFAULT_DIRECTORY_PERMISSIONS }

  describe "#initialize" do
    context "without `prefix`" do
      after_each do
        FileUtils.rm_rf(root)
      end

      it "expands the directory" do
        path = File.expand_path(root)

        expect(
          subject.expanded_directory
        ).to eq(path)
      end

      it "creates the given directory" do
        expect(
          File.directory?(subject.expanded_directory)
        ).to be_true
      end
    end

    context "with `prefix`" do
      let(prefix) { "prefix" }

      after_each do
        FileUtils.rm_rf(File.join(root, prefix))
        FileUtils.rm_rf(root)
      end

      it "expands the directory" do
        path = File.expand_path(File.join(root, prefix))

        expect(
          subject.expanded_directory
        ).to eq(path)
      end

      it "creates the given directory" do
        expect(
          File.directory?(File.join(subject.expanded_directory))
        ).to be_true
      end
    end

    context "with default directory permissions" do
      after_each do
        FileUtils.rm_rf(root)
      end

      it "sets directory permissions" do
        expect(File.info(subject.expanded_directory).permissions.value)
          .to eq(Shrine::Storage::FileSystem::DEFAULT_DIRECTORY_PERMISSIONS)
      end
    end

    context "with 0x500 directory permissions" do
      let(directory_permissions) { 0o500 }

      after_each do
        FileUtils.rm_rf(root)
      end

      it "sets directory permissions" do
        expect(
          File.info(subject.expanded_directory).permissions.value
        ).to eq(0o500)
      end
    end
  end

  describe "#upload" do
    after_each do
      FileUtils.rm_rf(root)
    end

    it "creates subdirectories" do
      subject.upload(FakeIO.new, "a/a/a.jpg")

      expect(
        subject.exists?("a/a/a.jpg")
      ).to be_true
    end

    it "copies full file content" do
      subject.upload(FakeIO.new("A" * 20_000), "foo.jpg")

      expect(
        subject.open("foo.jpg").size
      ).to eq(20_000)
    end

    context "with 0o600 permissions" do
      let(permissions) { 0o600 }

      it "sets file permissions" do
        subject.upload(FakeIO.new, "foo.jpg")

        expect(
          subject.open("foo.jpg").path
        ).to have_permissions(permissions)
      end
    end

    context "with 0o744 directory permissions" do
      let(directory_permissions) { 0o744 }

      it "sets directory permissions on intermediary directories" do
        subject.upload(FakeIO.new, "a/b/c/file.jpg")

        expect(
          "#{subject.expanded_directory}/a"
        ).to have_permissions(directory_permissions)

        expect(
          "#{subject.expanded_directory}/a/b"
        ).to have_permissions(directory_permissions)

        expect(
          "#{subject.expanded_directory}/a/b/c"
        ).to have_permissions(directory_permissions)
      end
    end

    describe "on :move" do
      it "moves movable files" do
        file = tempfile("file")

        subject.upload(file, "foo", move: true)

        expect(
          subject.open("foo").gets_to_end
        ).to eq("file")

        expect(
          File.exists?(file.path)
        ).to be_false
      end

      it "creates subdirectories" do
        file = tempfile("file")

        subject.upload(file, "a/a/a.jpg", move: true)

        expect(
          subject.exists?("a/a/a.jpg")
        ).to be_true
      end

      # it "cleans moved file's directory" do
      #   uploaded_file = subject.upload(fakeio, location: "a/a/a.jpg")
      #   subject.upload(uploaded_file, "b.jpg", move: true)

      #   expect(
      #     subject.exists?("a/a")
      #   ).to be_false
      # end

      context "with 0o600 permissions" do
        let(permissions) { 0o600 }

        it "sets file permissions" do
          subject.upload(tempfile("file"), "bar.jpg", move: true)

          expect(
            subject.open("bar.jpg").path
          ).to have_permissions(permissions)
        end
      end
    end
  end

  describe "#open" do
  end

  describe "#url" do
    after_each do
      FileUtils.rm_rf(root)
    end

    it "returns the full path without :prefix" do
      subject.upload(fakeio, "foo.jpg")

      expect(
        subject.url("foo.jpg")
      ).to eq("#{subject.expanded_directory}/foo.jpg")
    end

    it "applies a host without :prefix" do
      subject.upload(fakeio, "foo.jpg")

      expect(
        subject.url("foo.jpg", host: "http://124.83.12.24")
      ).to eq("http://124.83.12.24#{root}/foo.jpg")
    end

    context "with `prefix`" do
      let(prefix) { "prefix" }

      it "returns the path relative to the :prefix" do
        subject.upload(fakeio, "foo.jpg")

        expect(
          subject.url("foo.jpg")
        ).to eq("/#{prefix}/foo.jpg")
      end

      it "accepts a host with :prefix" do
        subject.upload(fakeio, "foo.jpg")

        expect(
          subject.url("foo.jpg", host: "http://abc123.cloudfront.net")
        ).to eq("http://abc123.cloudfront.net/#{prefix}/foo.jpg")
      end
    end
  end

  describe "#delete" do
  end

  describe "#delete_prefixed" do
  end

  describe "#clear!" do
  end

  describe "#path" do
    it "returns path to the file" do
      expect(
        subject.path("foo/bar/baz")
      ).to eq("#{root}/foo/bar/baz")
    end
  end

  describe "#clean" do
  end
end
