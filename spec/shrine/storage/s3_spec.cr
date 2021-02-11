require "../../spec_helper"
require "awscr-s3"

Spectator.describe Shrine::Storage::S3 do
  subject {
    Shrine::Storage::S3.new(
      bucket: bucket,
      client: client,
      prefix: prefix,
      upload_options: {"x-amz-acl" => "private"}
    )
  }

  let(client) { Awscr::S3::Client.new("us-east-2", "test_key", "test_secret") }
  let(bucket) { "test" }
  let(prefix) { nil }
  let(id) { "ex" }

  let(metadata) {
    Shrine::UploadedFile::MetadataType{
      "filename"  => id,
      "mime_type" => "image/jpeg",
      "size"      => "50",
    }
  }

  describe "#initialize" do
    context "without `prefix`" do
      it "object_key" do
        expect(
          subject.object_key(id)
        ).to eq(id)
      end
    end

    context "with `prefix`" do
      let(prefix) { "prefix" }

      it "object_key" do
        expect(
          subject.object_key(id)
        ).to eq("#{prefix}/#{id}")
      end
    end
  end

  describe "#upload" do
    context "without `prefix`" do
      it "creates subdirectories" do
        WebMock.stub(:put, "https://s3-us-east-2.amazonaws.com/test/object?")
          .with(body: "", headers: {"Content-Type" => "binary/octet-stream"})
          .to_return(status: 200, body: "", headers: {"ETag" => "etag"})

        expect(
          subject.upload(FakeIO.new, "object")
        ).to be_true
      end
    end

    context "with `prefix`" do
      let(prefix) { "prefix" }

      it "creates subdirectories" do
        WebMock.stub(:put, "https://s3-us-east-2.amazonaws.com/test/#{prefix}/a/a/a.jpg?")
          .with(body: "", headers: {"Content-Type" => "binary/octet-stream"})
          .to_return(status: 200, body: "", headers: {"ETag" => "etag"})

        expect(
          subject.upload(FakeIO.new, "a/a/a.jpg")
        ).to be_true
      end
    end

    context "with metadata" do
      it "file uploads" do
        WebMock.stub(:put, "https://s3-us-east-2.amazonaws.com/test/a/a/a.jpg?")
          .with(body: "", headers: {"Content-Type" => "binary/octet-stream", "Content-Disposition" => "inline; filename=\"ex\"; filename*=UTF-8''ex"})
          .to_return(status: 200, body: "", headers: {"ETag" => "etag"})

        expect(
          subject.upload(FakeIO.new, "a/a/a.jpg", metadata)
        ).to be_true
      end
    end
  end

  describe "#exists?" do
    it "file exists" do
      WebMock.stub(:head, "https://s3-us-east-2.amazonaws.com/test/a/a/a.jpg?")
        .to_return(status: 200, headers: {"Content-Type" => "binary/octet-stream", "Last-Modified" => "Sun, 10 Jan 2020 4:47:46 UTC"})
      expect(
        subject.exists?("a/a/a.jpg")
      ).to be_true
    end

    it "file does not exist" do
      WebMock.stub(:head, "https://s3-us-east-2.amazonaws.com/test/ex.jpg?")
        .to_return(status: 404)
      expect(
        subject.exists?("ex.jpg")
      ).to be_false
    end
  end

  describe "#url" do
    context "without `prefix`" do
      it "returns the full url" do
        expect(
          subject.url("foo.jpg")
        ).to match(/https:\/\/s3-#{client.@region}.amazonaws.com\/#{bucket}\/foo.jpg/)
      end
    end

    context "with `prefix`" do
      let(prefix) { "prefix" }
      it "returns the full url" do
        expect(
          subject.url("foo.jpg")
        ).to match(/https:\/\/s3-#{client.@region}.amazonaws.com\/#{bucket}\/#{prefix}\/foo.jpg/)
      end
    end
  end

  describe "#open" do
    context "without `prefix`" do
      it "returns a IO-like object" do
        WebMock.stub(:get, "https://s3-us-east-2.amazonaws.com/test/foo.jpg?")
          .to_return(body_io: FakeIO.new)
        expect(
          subject.open("foo.jpg")
        ).to be_kind_of(IO::Memory)
      end
    end
    context "with `prefix`" do
      let(prefix) { "prefix" }
      it "returns a IO-like object" do
        WebMock.stub(:get, "https://s3-us-east-2.amazonaws.com/test/#{prefix}/foo.jpg?")
          .to_return(body_io: FakeIO.new)
        expect(
          subject.open("foo.jpg")
        ).to be_kind_of(IO::Memory)
      end
    end
  end

  describe "#delete" do
    context "without `prefix`" do
      it "deletes objects" do
        WebMock.stub(:delete, "https://s3-us-east-2.amazonaws.com/test/foo.jpg?")
          .to_return(status: 204)
        expect(
          subject.delete("foo.jpg")
        ).to be_true
      end
    end

    context "with `prefix`" do
      let(prefix) { "prefix" }
      it "deletes objects" do
        WebMock.stub(:delete, "https://s3-us-east-2.amazonaws.com/test/#{prefix}/foo.jpg?")
          .to_return(status: 204)
        expect(
          subject.delete("foo.jpg")
        ).to be_true
      end
    end
  end
end
