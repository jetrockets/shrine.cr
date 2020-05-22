require "habitat"

class Shrine
  module Storage
    abstract class Base
      getter? clean : Bool = true

      # uploads `io` to the location `id`, can accept upload options
      abstract def upload(io : IO | UploadedFile, id : String, move = false, **options)

      # returns the remote file as an IO-like object
      abstract def open(id : String, **options) : IO

      # returns URL to the remote file, can accept URL options
      abstract def url(id : String, **options) : String

      # returns whether the file exists on storage
      abstract def exists?(id : String) : Bool

      # deletes the file from the storage
      abstract def delete(id : String)

      # cleans the path in the storage
      abstract def clean(path : String)
    end
  end
end
