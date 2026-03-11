require "./base"
require "awscr-s3"
require "content_disposition"

class Shrine
  module Storage
    class S3 < Storage::Base
      getter bucket : String
      getter client : Awscr::S3::Client
      getter? public : Bool
      getter prefix : String?

      def initialize(
        @bucket : String,
        @client : Awscr::S3::Client? = nil,
        @prefix : String? = nil,
        @upload_options : Hash(String, String) = Hash(String, String).new,
        @public : Bool = false,
        region : String? = nil,
        aws_access_key : String? = nil,
        aws_secret_key : String? = nil,
        endpoint : String? = nil
      )
        # Create client if not provided
        if @client.nil?
          @client = Awscr::S3::Client.new(
            region.to_s,
            aws_access_key.to_s,
            aws_secret_key.to_s,
            endpoint: endpoint
          )
        end
      end

      def upload(io : IO | UploadedFile, id : String, move = false, **options)
        # Prepare headers
        headers = prepare_headers(options)
        
        # Get IO object
        file_io = io.is_a?(UploadedFile) ? io.io : io
        
        # Upload to S3
        client.put_object(
          bucket, 
          object_key(id), 
          file_io.gets_to_end, 
          headers
        )
        
        true
      end

      def upload(io : IO | UploadedFile, id : String, metadata : Shrine::UploadedFile::MetadataType, move = false, **options)
        upload(io, id, move, **options.merge(metadata: metadata))
      end

      def open(id : String, **options) : IO
        response = client.get_object(bucket, object_key(id))
        IO::Memory.new(response.body)
      rescue e : Awscr::S3::Exception
        raise FileNotFound.new("File #{id} not found in S3: #{e.message}")
      end

      def url(id : String, **options) : String
        presigned = Awscr::S3::Presigned::Url.new(
          Awscr::S3::Presigned::Url::Options.new(
            aws_access_key: client.@aws_access_key,
            aws_secret_key: client.@aws_secret_key,
            region: client.@region,
            object: "/#{object_key(id)}",
            bucket: bucket
          )
        )
        presigned.for(:get, **options)
      end

      def exists?(id : String) : Bool
        client.head_object(bucket, object: object_key(id))
        true
      rescue Awscr::S3::Exception
        false
      end

      def delete(id : String)
        client.delete_object(bucket, object_key(id))
      end

      def clean(path : String)
        # S3 doesn't have directories, nothing to clean
      end

      def path(id : String) : String
        object_key(id)
      end

      def object_key(id : String) : String
        prefix ? "#{@prefix}/#{id}" : id
      end

      private def prepare_headers(options)
        headers = @upload_options.dup
        
        # Handle content disposition
        if metadata = options[:metadata]?.try(&.as(Shrine::UploadedFile::MetadataType))
          if filename = metadata["filename"]?
            headers["Content-Disposition"] = ContentDisposition.inline(filename.to_s)
          end
        end
        
        # Handle public access
        headers["x-amz-acl"] = "public-read" if public?
        
        # Merge any additional options
        options.each do |key, value|
          headers[key.to_s] = value.to_s
        end
        
        headers
      end
    end
  end
end