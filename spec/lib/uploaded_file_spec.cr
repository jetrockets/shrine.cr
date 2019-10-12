require "../spec_helper"

Spectator.describe Shrine::UploadedFile do
  include ShrineHelpers
  include FileHelpers

  subject(uploaded_file) {
    Shrine::UploadedFile.new(id, :store, metadata)
  }

  # let(uploader) { u = uploader(:store)}
  let(id) { "foo" }
  let(metadata) { NamedTuple.new }

  describe "#initialize" do
    it "initializes metadata if absent" do
      metadata = subject.metadata

      expect(
        metadata
      ).to be_a(Shrine::UploadedFile::Metadata)

      expect(
        metadata
      ).to have_attributes(size: nil, mime_type: nil, filename: nil)
    end
  end

  describe "#original_filename" do
    context "without filename in `metadata`" do
      it "returns nil" do
        expect(uploaded_file.original_filename).to be_nil
      end
    end

    context "with filename in `metadata`" do
      let(metadata) { NamedTuple.new(filename: "foo.jpg") }

      it "returns filename from metadata" do
        expect(uploaded_file.original_filename).to eq(metadata[:filename])
      end
    end

    context "with blank filename in `metadata`" do
      let(metadata) { NamedTuple.new(filename: nil) }

      it "returns nil" do
        expect(uploaded_file.original_filename).to be_nil
      end
    end
  end

  describe "#extension" do
    subject { uploaded_file.extension }

    context "with extension in `id`" do
      let(id) { "foo.jpg" }
      it is_expected.to eq("jpg")
    end

    context "without extension in `id`" do
      let(id) { "foo" }
      it is_expected.to be_nil
    end

    context "with filename and extension in `metadata`" do
      let(metadata) { NamedTuple.new(filename: "foo.jpg") }
      it is_expected.to eq("jpg")
    end

    context "with filename in `metadata`" do
      let(metadata) { NamedTuple.new(filename: "foo") }
      it is_expected.to be_nil
    end

    context "without filename in `metadata`" do
      it is_expected.to be_nil
    end

    context "with extension in `id` and in `metadata`" do
      let(id) { "foo.jpg" }
      let(metadata) { NamedTuple.new(filename: "foo.png") }

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
      let(metadata) { NamedTuple.new(filename: "foo.PNG") }

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
      let(metadata) { NamedTuple.new(size: 50) }

      it "returns size from metadata" do
        expect(uploaded_file.size).to eq(metadata[:size])
      end
    end

    context "with blank size in `metadata`" do
      let(metadata) { NamedTuple.new(size: nil) }

      it "returns nil" do
        expect(uploaded_file.size).to be_nil
      end
    end

    context "with size as String in `metadata`" do
      let(metadata) { NamedTuple.new(size: "50") }

      it "converts the value to integer" do
        expect(uploaded_file.size).to eq(50)
      end
    end
  end
end
