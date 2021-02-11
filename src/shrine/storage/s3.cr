require "./base"

require "awscr-s3"
require "content_disposition"

class Shrine
  module Storage
    class S3 < Storage::Base
      getter bucket : String
      getter client : Awscr::S3::Client
      getter? public : Bool
      getter uploader : Awscr::S3::FileUploader

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
      def initialize(
        @bucket : String,
        @client : Awscr::S3::Client?,
        @prefix : String? = nil,
        @upload_options : Hash(String, String) = Hash(String, String).new,
        @public : Bool = false
      )
        @uploader = Awscr::S3::FileUploader.new(client: client)
      end

      # Copies the file into the given location.
      #
      def upload(io : IO | UploadedFile, id : String, move = false, **upload_options)
        options = Hash(String, String).new
        if (metadata = upload_options[:metadata]?) && metadata.is_a?(Shrine::UploadedFile::MetadataType)
          options["Content-Disposition"] = ContentDisposition.inline(metadata["filename"].to_s) if metadata["filename"]
        end
        options["x-amz-acl"] = "public-read" if public?

        options.merge!(@upload_options)
        upload_options.each { |key, value| options[key.to_s] = value.to_s }

        io = io.io if io.is_a?(UploadedFile)
        uploader.upload(bucket, object_key(id), io, options)
      end

      def upload(io : IO | UploadedFile, id : String, metadata : Shrine::UploadedFile::MetadataType, move = false, **upload_options)
        upload(io, id, move, **(upload_options.merge(metadata: metadata)))
      end

      # Returns a IO object from S3
      def open(id : String, **options) : IO
        io = IO::Memory.new
        client.get_object(bucket, object_key(id)) do |obj|
          io << obj
        end

        # io
        # client.get_object(bucket, object_key(id)).body_io
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

      def path(id : String)
        object_key(id)
      end

      # Returns object key with potential prefix.
      def object_key(id : String) : String
        @prefix ? [@prefix, id].join("/") : id
      end
    end
  end
end
