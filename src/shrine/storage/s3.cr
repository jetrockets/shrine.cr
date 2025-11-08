require "./base"

require "awscr-s3"
require "content_disposition"

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
      def initialize(
        @bucket : String,
        @client : Awscr::S3::Client?,
        @prefix : String? = nil,
        @upload_options : Hash(String, String) = Hash(String, String).new,
        @public : Bool = false,
      )
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
        client.put_object(bucket, object_key(id), io.gets_to_end, options)

        true
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
      #
      # Behavior:
      # - If the underlying Awscr::S3::Client has a custom endpoint configured
      #   (for example when using MinIO), that endpoint will be used for the
      #   generated URL.
      # - Otherwise, a standard AWS S3 style URL is generated.
      #
      # Supported options (non-exhaustive, forwarded when present):
      # - :expires_in  :: Int32 | Int64  - expiration time in seconds
      # - :method      :: Symbol         - HTTP method for the presigned URL (default: :get)
      # - :public      :: Bool           - if true, attempt to generate a public URL
      # - :host        :: String         - override host name explicitly
      #
      # NOTE: This is intentionally opinionated and may differ from earlier
      # versions. It prefers correctness with custom endpoints over strict
      # backwards compatibility.
      def url(id : String, **options) : String
        method = (options[:method]? || :get).to_s.downcase
        expires_in = options[:expires_in]? || 86_400

        # Prefer explicit host override, otherwise derive from client endpoint
        # when available, and fall back to library defaults for AWS.
        host_name =
          if host = options[:host]?
            host.to_s
          elsif ep = client.@endpoint
            begin
              uri = URI.parse(ep.to_s)
              host = uri.host || ep.to_s
              if uri.port && uri.port != 80 && uri.port != 443
                "#{host}:#{uri.port}"
              else
                host
              end
            rescue URI::Error
              ep.to_s
            end
          else
            nil
          end

        presigned_options = Awscr::S3::Presigned::Url::Options.new(
          aws_access_key: client.@aws_access_key,
          aws_secret_key: client.@aws_secret_key,
          region: client.@region,
          object: "/#{object_key(id)}",
          bucket: bucket,
          host_name: host_name,
          expires: expires_in.to_i,
        )

        url = Awscr::S3::Presigned::Url.new(presigned_options)

        # Only :get is used internally today, but support overriding via :method
        # for future flexibility.
        presign_method =
          case method
          when "get" then :get
          when "put" then :put
          else
            :get
          end

        url.for(presign_method)
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
