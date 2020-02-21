require "./base"

require "awscr-s3"

class Shrine
  module Storage
    class S3 < Storage::Base
      getter bucket : String
      getter client : Awscr::S3::Client
      getter? public : Bool

      # Initializes a storage for uploading to S3. All options are forwarded to
      # [`Shrine::Storage::S3#initialize`], except the following:
      #
      # :bucket
      # : (Required). Name of the S3 bucket.
      #
      # :client
      # : By default an `Awscr::S3::Client` instance is created internally from
      #   additional options, but you can use this option to provide your own
      #   client.
      #
      # :prefix
      # : "Directory" inside the bucket to store files into.
      #
      # :upload_options
      # : Additional options that will be used for uploading files.
      #
      # :public
      # : Sets public access to all uploading files.
      #
      def initialize(@bucket : String, @client : Awscr::S3::Client?, @prefix : String? = nil,
                     @upload_options : Hash(String, String) = Hash(String, String).new, @public : Bool = false)
      end

      # Copies the file into the given location.
      def upload(io : IO, id : String, metadata : Shrine::UploadedFile::MetadataType? = nil, move = false, **upload_options)
        options = Hash(String, String).new
        options["x-amz-acl"] = "public-read" if public?
        uploader = Awscr::S3::FileUploader.new(client)

        upload_options = upload_options.map { |k, v| {k.to_s => v.to_s} }
        upload_options.each do |item|
          options.merge!(item)
        end
        options.merge!(@upload_options) if @upload_options
        uploader.upload(bucket, object_key(id), io, options)
      end

      # Returns a IO object from S3
      def open(id : String, **options) : IO
        io = IO::Memory.new
        client.get_object(bucket, object_key(id)) do |obj|
          io << obj
        end
      end

      # Returns the presigned URL to the file.
      def url(id : String, **options) : String
        presigned_options = Awscr::S3::Presigned::Url::Options.new(
          aws_access_key: client.@aws_access_key,
          aws_secret_key: client.@aws_secret_key,
          region: client.@region,
          object: "/#{object_key(id)}",
          bucket: bucket,
        )

        url = Awscr::S3::Presigned::Url.new(presigned_options)
        url.for(:get)
      end

      # Returns true if the file exists on the S3.
      def exists?(id : String) : Bool
        client.head_object(bucket, object: object_key(id))
        true
      rescue Awscr::S3::Exception
        false
      end

      # Delets the file, and by default deletes the containing directory if
      # it's empty.
      def delete(id : String) : Bool
        client.delete_object(bucket, object_key(id))
      end

      def clean(path)
      end

      # Returns object key with potential prefix.
      def object_key(id : String) : String
        @prefix ? [@prefix, id].join("/") : id
      end
    end
  end
end
