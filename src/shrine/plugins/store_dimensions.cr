require "pixie"

class Shrine
  module Plugins
    module StoreDimensions
      DEFAULT_OPTIONS = {
        analyzer: :built_in,
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
        def extract_metadata(io : IO)
          width, height = self.class.extract_dimensions(io)

          super.merge!({"width" => width, "height" => height})
        end
      end

      enum Tools
        BuiltIn
        Pixie
      end

      module FileMethods
        def width : Int32
          metadata["width"]
        end

        def height : Int32
          metadata["height"]
        end

        def dimensions : Tuple(Int32)
          {width, height} if width || height
        end
      end

      class DimensionsAnalyzer
        def initialize(@tool : Tools)
        end

        def call(io : IO)
          dimensions = case @tool
                       when Tools::BuiltIn
                         extract_with_built_in(io)
                       when Tools::Pixie
                         extract_with_pixie(io)
                       end

          io.rewind

          dimensions
        end

        private def extract_with_built_in(io)
          Shrine.with_file(io) do |file|
            dimensions = BuiltInAnalyzer.new(file).dimensions

            {dimensions[0], dimensions[1]}
          end
        end

        private def extract_with_pixie(io)
          Shrine.with_file(io) do |file|
            info = Pixie::ImageSet.new(file.path)

            {info.image_width.to_i, info.image_height.to_i}
          end
        rescue e
          raise Error.new(e.message)
        end
      end

      # A bare-bones wrapper for ImageMagick's identify command
      class BuiltInAnalyzer
        def initialize(@file : File)
        end

        # Extract dimensions from a given file
        def dimensions : Array(Int32)
          identify(["-format", "%[fx:w] %[fx:h]"]).split.map(&.to_i)
        end

        # Execute an identify command
        private def identify(args : Array(String) = Array(String).new) : String
          output = IO::Memory.new
          error = IO::Memory.new
          result = Process.run("identify",
            args: args.push(@file.path),
            shell: true, output: output, error: error)

          raise Error.new(error.to_s.strip) unless result.success?

          output.to_s.strip
        end
      end
    end
  end
end
