require "../spec_helper"

Spectator.describe Shrine::UploadedFile do
  include ShrineHelpers
  include FileHelpers

  subject(uploaded_file) {
    Shrine::UploadedFile.new(id, "cache", metadata)
  }

  let(id) { "foo" }

  let(metadata) {
    Shrine::UploadedFile::MetadataType{
      "filename"  => filename,
      "mime_type" => mime_type,
      "size"      => size,
    }
  }

  let(filename) { nil }
  let(mime_type) { nil }
  let(size) { nil }

  after_each do
    clear_storages
  end

  describe "#initialize" do
    it "initializes metadata if absent" do
      metadata = subject.metadata

      expect(
        metadata
      ).to be_a(Shrine::UploadedFile::MetadataType)
    end
  end

  describe "#original_filename" do
    context "without filename in `metadata`" do
      it "returns nil" do
        expect(uploaded_file.original_filename).to be_nil
      end
    end

    context "with filename in `metadata`" do
      let(filename) { "foo.jpg" }

      it "returns filename from metadata" do
        expect(uploaded_file.original_filename).to eq(filename)
      end
    end

    context "with blank filename in `metadata`" do
      let(filename) { nil }

      it "returns nil" do
        expect(uploaded_file.original_filename).to be_nil
      end
    end
  end

  describe "#extension" do
    subject { uploaded_file.extension }

    context "with extension in `id`" do
      let(id) { "foo.jpg" }
      it { is_expected.to eq("jpg") }
    end

    context "without extension in `id`" do
      let(id) { "foo" }
      it { is_expected.to be_nil }
    end

    context "with filename and extension in `metadata`" do
      let(filename) { "foo.jpg" }
      it { is_expected.to eq("jpg") }
    end

    context "with filename in `metadata`" do
      let(filename) { "foo" }
      it { is_expected.to be_nil }
    end

    context "without filename in `metadata`" do
      it { is_expected.to be_nil }
    end

    context "with extension in `id` and in `metadata`" do
      let(id) { "foo.jpg" }
      let(filename) { "foo.png" }

      it "prefers extension from id over one from filename" do
        expect(uploaded_file.extension).to eq("jpg")
      end
    end

    context "with UPCASED extension in `id`" do
      let(id) { "foo.JPG" }

      it "downcases the extracted extension" do
        expect(uploaded_file.extension).to eq("jpg")
      end
    end

    context "with UPCASED extension in `filename`" do
      let(filename) { "foo.PNG" }

      it "downcases the extracted extension" do
        expect(uploaded_file.extension).to eq("png")
      end
    end
  end

  describe "#size" do
    context "without size in `metadata`" do
      it "returns nil" do
        expect(uploaded_file.size).to be_nil
      end
    end

    context "with size in `metadata`" do
      let(size) { 50 }

      it "returns size from metadata" do
        expect(uploaded_file.size).to eq(size)
      end
    end

    context "with blank size in `metadata`" do
      it "returns nil" do
        expect(uploaded_file.size).to be_nil
      end
    end

    context "with size as String in `metadata`" do
      let(size) { "50" }

      it "converts the value to integer" do
        expect(uploaded_file.size).to eq(size.to_i)
      end
    end
  end

  describe "#mime_type" do
    context "with mime_type in `metadata`" do
      let(mime_type) { "image/jpeg" }

      it "returns mime_type from metadata" do
        expect(uploaded_file.mime_type).to eq(mime_type)
      end

      it "has #content_type alias" do
        expect(uploaded_file.content_type).to eq(mime_type)
      end
    end

    context "with blank mime_type in `metadata`" do
      it "returns nil as a mime_type" do
        expect(uploaded_file.mime_type).to be_nil
      end
    end

    context "without mime_type in `metadata`" do
      it "returns nil as a mime_type" do
        expect(uploaded_file.mime_type).to be_nil
      end
    end
  end

  describe "#close" do
    it "closes the underlying IO object" do
      uploaded_file = uploader.upload(fakeio)
      io = uploaded_file.io
      uploaded_file.close

      expect(io.closed?).to be_true
    end
  end

  describe "#url" do
    it "delegates to underlying storage" do
      expect(uploaded_file.url).to eq("memory://foo")
    end
  end

  describe "#exists?" do
    it "delegates to underlying storage" do
      uploaded_file = uploader.upload(fakeio)
      expect(uploaded_file.exists?).to be_true

      expect(subject.exists?).to be_false
    end
  end

  describe "#open" do
    it "returns the underlying IO if no block given" do
      uploaded_file = uploader.upload(fakeio)

      expect(uploaded_file.open).to be_an(IO)
      expect(uploaded_file.open.closed?).to be_false
    end

    it "closes the previuos IO" do
      uploaded_file = uploader.upload(fakeio)
      io1 = uploaded_file.open
      io2 = uploaded_file.open

      expect(io1).not_to eq(io2)
      expect(io1.closed?).to be_true
      expect(io2.closed?).to be_false
    end

    it "yields to the block if it's given" do
      uploaded_file = uploader.upload(fakeio)

      called = false
      uploaded_file.open { called = true }
      expect(called).to be_true
    end

    it "yields the opened IO" do
      uploaded_file = uploader.upload(fakeio("file"))
      uploaded_file.open do |io|
        io = io.not_nil!

        expect(io).to be_an(IO)
        expect(io.gets_to_end).to eq("file")
      end
    end

    it "makes itself open as well" do
      uploaded_file = uploader.upload(fakeio)
      uploaded_file.open do |io|
        expect(io).to eq(uploaded_file.io)
      end
    end

    it "closes the IO after block finishes" do
      uploaded_file = uploader.upload(fakeio)

      dup = IO::Memory.new
      uploaded_file.open { |io| dup = io.not_nil! }
      expect { dup.gets_to_end }.to raise_error(IO::Error)
    end

    it "resets the uploaded file ready to be opened again" do
      uploaded_file = uploader.upload(fakeio("file"))
      uploaded_file.open { }

      expect(uploaded_file.gets_to_end).to eq("file")
    end

    it "opens even if it was closed" do
      uploaded_file = uploader.upload(fakeio("file"))
      uploaded_file.gets_to_end
      uploaded_file.close
      uploaded_file.open { |io|
        expect(io.not_nil!.gets_to_end).to eq("file")
      }
    end

    it "closes the file even if error has occured" do
      uploaded_file = uploader.upload(fakeio)
      dup = IO::Memory.new

      expect {
        uploaded_file.open do |io|
          dup = io.not_nil!
          raise "error ocurred"
        end
      }.to raise_error(Exception)

      expect(dup.closed?).to be_true
    end
  end

  describe "#download" do
    it "downloads file content to a Tempfile" do
      uploaded_file = uploader.upload(fakeio("file"))
      downloaded = uploaded_file.download

      expect(downloaded).to be_a(File)
      expect(downloaded.closed?).to be_false
      expect(downloaded.gets_to_end).to eq("file")
    end

    it "applies extension from #id" do
      uploaded_file = uploader.upload(fakeio, location: "foo.jpg")

      expect(
        uploaded_file.download.path
      ).to match(/\.jpg$/)
    end

    it "applies extension from #original_filename" do
      uploaded_file = uploader.upload(fakeio(filename: "foo.jpg"), location: "foo")

      expect(
        uploaded_file.download.path
      ).to match(/\.jpg$/)
    end

    it "yields the tempfile if block is given" do
      uploaded_file = uploader.upload(fakeio)

      uploaded_file.download do |tempfile|
        block = tempfile

        expect(block).to be_a(File)
      end
    end

    it "returns the block return value" do
      uploaded_file = uploader.upload(fakeio)

      expect {
        uploaded_file.download { |_tempfile| "result" }
      }.to eq("result")
    end

    it "closes and deletes the tempfile after the block" do
      uploaded_file = uploader.upload(fakeio)

      tempfile = uploaded_file.download do |_tempfile|
        expect(_tempfile.closed?).to be_false
        _tempfile
      end

      expect(tempfile.closed?).to be_true
      expect(File.exists?(tempfile.path)).to be_false
    end
  end

  describe "#stream" do
    it "opens and closes the file after streaming if it was not open" do
      uploaded_file = uploader.upload(fakeio("content"))
      uploaded_file.stream(destination = IO::Memory.new)

      expect(destination.to_s).to eq("content")
      expect(uploaded_file.opened?).to be_false
    end
  end

  describe "#replace" do
    it "uploads another file to the same location" do
      uploaded_file = uploader.upload(fakeio("file"))
      new_uploaded_file = uploaded_file.replace(fakeio("replaced"))

      expect(new_uploaded_file.id).to eq(uploaded_file.id)
      expect(new_uploaded_file.gets_to_end).to eq("replaced")
      expect(new_uploaded_file.size).to eq("replaced".size)
    end
  end

  describe "#delete" do
    it "delegates to underlying storage" do
      uploaded_file = uploader.upload(fakeio)
      uploaded_file.delete

      expect(uploaded_file.exists?).to be_false
    end
  end

  describe "#data" do
    let(metadata) {
      Shrine::UploadedFile::MetadataType{
        "foo" => "bar",
      }
    }

    it "returns uploaded file data hash" do
      expect(uploaded_file.data).to eq(
        {
          "id"          => id,
          "storage_key" => "cache",
          "metadata"    => metadata,
        }
      )
    end
  end
end
