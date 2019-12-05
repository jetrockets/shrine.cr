require "habitat"

class Shrine
  module Storage
    abstract class Base
      # macro inherited
      #   puts "{{@type.name.id}} < Base"
      # end

      # Habitat.create do
      #   setting clean : Bool = true
      # end

      # uploads `io` to the location `id`, can accept upload options
      abstract def upload(io, id : String, move = false, **options)

      # returns the remote file as an IO-like object
      abstract def open(id, **options)

      # returns URL to the remote file, can accept URL options
      abstract def url(id, **options)

      # returns whether the file exists on storage
      abstract def exists?(id)

      # deletes the file from the storage
      abstract def delete(id)
    end
  end
end
