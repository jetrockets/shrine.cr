require "../../spec_helper"

# Fake clients used for behavior specs
class FakeClientForShrineSpec < Awscr::S3::Client
  getter put_calls = [] of Tuple(String, String, String, Hash(String, String))

  def initialize
    super("key", "secret", "us-east-2")
  end

  def put_object(bucket, key, body, options)
    put_calls << {bucket, key, body, options}
    true
  end

  # minimal interface required by url implementation
  def aws_access_key
    "key"
  end

  def aws_secret_key
    "secret"
  end

  def region
    "us-east-2"
  end

  def endpoint
    nil
  end
end

class ExistsClientForShrineSpec < Awscr::S3::Client
  def head_object(bucket, object : String? = nil, **options)
    if object == "exists"
      true
    else
      raise Awscr::S3::Exception.new("Missing")
    end
  end
end

class DeleteClientForShrineSpec < Awscr::S3::Client
  getter deleted = [] of String

  def delete_object(bucket, object : String? = nil, **options)
    deleted << object if object
    true
  end
end

describe Shrine::Storage::S3 do
  it "builds object_key with and without prefix" do
    client = Awscr::S3::Client.new("key", "secret", "region")

    storage = Shrine::Storage::S3.new("bucket", client)
    storage.object_key("id").should eq "id"

    storage_prefixed = Shrine::Storage::S3.new("bucket", client, "prefix")
    storage_prefixed.object_key("id").should eq "prefix/id"
  end

  it "generates URLs with and without prefix" do
    client = Awscr::S3::Client.new("key", "secret", "us-east-2")

    storage = Shrine::Storage::S3.new("bucket", client)
    url = storage.url("foo.jpg")
    url.should contain("bucket")
    url.should contain("foo.jpg")

    prefixed = Shrine::Storage::S3.new("bucket", client, "prefix")
    prefixed_url = prefixed.url("foo.jpg")
    prefixed_url.should contain("bucket")
    prefixed_url.should contain("prefix/foo.jpg")
  end

  it "uses custom endpoint host for URLs" do
    client = Awscr::S3::Client.new("key", "secret", "us-east-2", endpoint: "http://localhost:9000")
    storage = Shrine::Storage::S3.new("bucket", client)

    url = storage.url("foo.jpg")
    url.should contain("localhost:9000")
    url.should contain("bucket")
    url.should contain("foo.jpg")
  end

  it "uses custom endpoint with non-default port" do
    client = Awscr::S3::Client.new("key", "secret", "us-east-2", endpoint: "http://127.0.0.1:9000")
    storage = Shrine::Storage::S3.new("bucket", client)

    url = storage.url("foo.jpg")
    url.should contain("127.0.0.1:9000")
    url.should contain("bucket")
    url.should contain("foo.jpg")
  end

  it "allows overriding host via :host option" do
    client = Awscr::S3::Client.new("key", "secret", "us-east-2")
    storage = Shrine::Storage::S3.new("bucket", client)

    url = storage.url("foo.jpg", host: "cdn.example.com")
    url.should contain("cdn.example.com")
    url.should contain("bucket")
    url.should contain("foo.jpg")
  end

  it "accepts different HTTP methods without raising" do
    client = Awscr::S3::Client.new("key", "secret", "us-east-2")
    storage = Shrine::Storage::S3.new("bucket", client)

    # These should all succeed and return a URL string
    storage.url("foo-get.jpg", method: :get).should be_a(String)
    storage.url("foo-put.jpg", method: :put).should be_a(String)

    # Unknown/unsupported methods should gracefully fall back to :get
    storage.url("foo-head.jpg", method: :head).should be_a(String)
    storage.url("foo-post.jpg", method: :post).should be_a(String)
    storage.url("foo-unknown.jpg", method: :unknown).should be_a(String)
  end

  it "uses metadata and public flag when uploading" do
    client = FakeClientForShrineSpec.new
    storage = Shrine::Storage::S3.new("bucket", client, nil, {"x-default" => "1"}, true)

    metadata = Shrine::UploadedFile::MetadataType{"filename" => "name.txt"}
    storage.upload(IO::Memory.new("body"), "id", metadata: metadata, custom: "2")

    call = client.put_calls.first
    call[0].should eq "bucket"
    call[1].should eq "id"
    call[3]["Content-Disposition"].should contain "name.txt"
    call[3]["x-amz-acl"].should eq "public-read"
    call[3]["x-default"].should eq "1"
    call[3]["custom"].should eq "2"
  end

  it "exists? returns true/false based on head_object" do
    client = ExistsClientForShrineSpec.new("key", "secret", "us-east-2")
    storage = Shrine::Storage::S3.new("bucket", client)

    storage.exists?("exists").should be_true
    storage.exists?("missing").should be_false
  end

  it "delete delegates to client" do
    client = DeleteClientForShrineSpec.new("key", "secret", "us-east-2")
    storage = Shrine::Storage::S3.new("bucket", client)

    storage.delete("id").should be_true
    client.deleted.should eq ["id"]
  end
end
