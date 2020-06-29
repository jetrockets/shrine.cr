require "fastimage"

class Shrine
  module Plugins
    module StoreDimensions
      DEFAULT_OPTIONS = {
        analyzer: :fastimage,
      }

      module ClassMethods
        # Determines the dimensions of the IO object by calling the specified
        # analyzer.
        def extract_dimensions(io)
          config = plugin_settings.store_dimensions
          analyzer = dimensions_analyzer(config[:analyzer])

          dimensions = analyzer.call(io)
          io.rewind

          dimensions
        end

        # Returns a hash of built-in MIME type analyzers, where keys are
        # analyzer names and values are `#call`-able objects which accepts the
        # IO object.
        def dimensions_analyzers
          StoreDimensions::Tools
        end

        # Returns callable mime type analyzer object.
        def dimensions_analyzer(name : Tools)
          DimensionsAnalyzer.new(name)
        end
      end

      module InstanceMethods
        # We update the metadata with "width" and "height".
        private def extract_metadata(io, **options) : Shrine::UploadedFile::MetadataType
          width, height = self.class.extract_dimensions(io).as(Tuple(UInt16, UInt16))

          super.merge({"width" => width, "height" => height})
        end
      end

      enum Tools
        FastImage
        Identify
      end

      module FileMethods
        def width : UInt16
          metadata["width"]
        end

        def height : UInt16
          metadata["height"]
        end

        def dimensions : Tuple(UInt16)
          {width, height} if width || height
        end
      end

      class DimensionsAnalyzer
        def initialize(@tool : Tools)
        end

        def call(io : IO) : Tuple(UInt16, UInt16)
          dimensions = case @tool
                       when Tools::FastImage
                         extract_with_fastimage(io)
                       when Tools::Identify
                         extract_with_identify(io)
                       else
                         raise Error.new "Unknown tool #{@tool} for StoreDimensions plugin"
                       end

          io.rewind

          dimensions
        end

        private def extract_with_fastimage(io)
          FastImage.dimensions!(io)
        rescue FastImage::Error
          raise Error.new("Cannot fetch dimensions for #{io}")
        end

        private def extract_with_identify(io)
          IdentifyAnalyzer.new(io).dimensions
        end
      end

      # A bare-bones wrapper for ImageMagick's identify command
      class IdentifyAnalyzer
        def initialize(@io : IO)
        end

        # Extract dimensions from a given file
        def dimensions : Tuple(UInt16, UInt16)
          dimensions = identify(["-format", "%[fx:w] %[fx:h]"]).split.map(&.to_u16)
          {dimensions[0], dimensions[1]}
        end

        # Execute an identify command
        private def identify(args : Array(String) = Array(String).new) : String
          stdout = IO::Memory.new
          stderr = IO::Memory.new
          result = Process.run("identify",
            args: args.push("-"),
            output: stdout,
            error: stderr,
            input: @io
          )

          raise Error.new "identify command failed: #{stderr}" unless result.success?

          stdout.to_s.strip
        rescue RuntimeError
          raise Error.new("identify command-line tool is not installed")
        end
      end
    end
  end
end
