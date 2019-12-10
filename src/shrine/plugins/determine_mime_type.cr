require "mime"

class Shrine
  module Plugins
    module DetermineMimeType
      DEFAULT_OPTIONS = {
        analyzer: :file,
      }

      module ClassMethods
        # Determines the MIME type of the IO object by calling the specified
        # analyzer.
        def determine_mime_type(io)
          config = plugin_settings.determine_mime_type
          analyzer = mime_type_analyzer(config[:analyzer])

          mime_type = analyzer.call(io)
          io.rewind

          mime_type
        end

        # Returns a hash of built-in MIME type analyzers, where keys are
        # analyzer names and values are `#call`-able objects which accepts the
        # IO object.
        def mime_type_analyzers
          MimeTypeAnalyzer::Tools
        end

        # Returns callable mime type analyzer object.
        def mime_type_analyzer(name : Tools)
          MimeTypeAnalyzer.new(name)
        end
      end

      module InstanceMethods
        # Calls the configured MIME type analyzer.
        private def extract_mime_type(io)
          self.class.determine_mime_type(io)
        end
      end

      enum Tools
        File
        Mime
        ContentType
      end

      class MimeTypeAnalyzer
        def initialize(@tool : Tools)
        end

        def call(io, **options)
          mime_type = case @tool
                      when Tools::File
                        extract_with_file(io, options)
                      when Tools::Mime
                        extract_with_mime(io, options)
                      when Tools::ContentType
                        extract_with_content_type(io, options)
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
            raise Error.new "file command failed: #{stderr}"
          end
        rescue RuntimeError
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
