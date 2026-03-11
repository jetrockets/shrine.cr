require 'mime'

 module Shrine
   module DetermineMimeType
      def mime_type(filename)    
        MIME.from_filename?(filename) || "application/octet-stream
        end 
    end 
 end 