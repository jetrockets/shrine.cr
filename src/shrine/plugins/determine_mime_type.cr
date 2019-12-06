require "mime"

class Shrine
  module Plugins
    module DetermineMimeType
      DEFAULT_OPTIONS = {
        analyzer: :file
      }

      module ClassMethods
        # Determines the MIME type of the IO object by calling the specified
        # analyzer.
        def determine_mime_type(io)
          config = plugin_settings.determine_mime_type
          analyzer = mime_type_analyzer(config[:analyzer]) # if analyzer.is_a?(Symbol)

          mime_type = analyzer.call(io)
          io.rewind

          mime_type
        end


        # Returns a hash of built-in MIME type analyzers, where keys are
        # analyzer names and values are `#call`-able objects which accepts the
        # IO object.
        def mime_type_analyzers
          MimeTypeAnalyzer::SUPPORTED_TOOLS
        end

        # Returns callable mime type analyzer object.
        def mime_type_analyzer(name : Symbol)
          MimeTypeAnalyzer.new(name)
        end
      end

      module InstanceMethods
        # Calls the configured MIME type analyzer.
        private def extract_mime_type(io)
          self.class.determine_mime_type(io)
        end
      end

      class MimeTypeAnalyzer
        # SUPPORTED_TOOLS = {
        #   file: -> { extract_with_file },
        #   mime: -> { extract_with_mime },
        #   content_type: -> { extract_with_content_type }
        # }
        MAGIC_NUMBER = 256 * 1024

        def initialize(@tool : Symbol)
          # raise Error, "unknown mime type analyzer #{tool.inspect}, supported analyzers are: #{SUPPORTED_TOOLS.join(",")}" unless SUPPORTED_TOOLS.include?(tool)
        end

        def call(io, **options)
          mime_type = case @tool
                      when :file
                        extract_with_file(io, {a: 1})
                      when :mime
                        extract_with_mime(io, {a: 1})
                      when :content_type
                        extract_with_content_type(io, {a: 1})
                      end

          io.rewind

          mime_type
        end

        private def extract_with_file(io : IO, options)
          return nil if io.size.try &.zero? # file command returns "application/x-empty" for empty files

          stdout = IO::Memory.new
          stderr = IO::Memory.new
          status = Process.run("file", args: ["--mime-type", "--brief", "-"], output: stdout, error: stderr, input: io)

          if status.success?
            io.rewind
            stdout.to_s.strip
          else
            raise Error.new "file command failed: #{stderr.to_s}"
          end
        rescue Errno
          raise Error.new("file command-line tool is not installed")
        end

        private def extract_with_mime(io, options)
          if filename = extract_filename(io)
            MIME.from_filename?(filename)
          end
        end

        def extract_with_content_type(io, options)
          if io.responds_to?(:content_type) && io.content_type
            io.content_type.not_nil!.split(";").first
          end
        end

        def extract_filename(io)
          if io.responds_to?(:original_filename)
            io.original_filename
          elsif io.responds_to?(:path)
            File.basename(io.path)
          end
        end
      end
    end
  end
end
