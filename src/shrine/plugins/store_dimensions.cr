class Shrine
  module Plugins
    module StoreDimensions
      module InstanceMethods
        private def extract_dimensions(io : IO)
        end
      end

      class DimensionsAnalyzer
        SUPPORTED_TOOLS = {:crymagick, :identify, :pixie}

        def initialize(@tool : Symbol)
          unless SUPPORTED_TOOLS.include?(@tool)
            tools = SUPPORTED_TOOLS.join(",")
            raise "unknown dimensions analyzer #{@tool}, supported are #{tools}"
          end
        end

        private def extract_with_crymagick(io : IO)
        end

        private def extract_with_identify(io : IO)
          # status = Process.run("identify",
          #   args: ["-format", "%[fx:w]x%[fx:h]"],
          #   output: stdout, error: stderr, input: io)


        rescue RuntimeError
          raise "identify command-line tool is not installed"
        end

        private def extract_with_pixie(io : IO)
        end
      end
    end
  end
end
