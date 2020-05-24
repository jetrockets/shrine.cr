class Shrine
  module Plugins
    module Column
      abstract class BaseSerializer
        # Since we cannot make class level method abstract we raise NotImplementedError
        # https://github.com/crystal-lang/crystal/issues/5956
        #
        def self.dump(data)
          raise NotImplementedError.new("Implement method .dump")
        end

        def self.load(data)
          raise NotImplementedError.new("Implement method .load")
        end
      end

      class JsonSerializer < BaseSerializer
        def self.dump(data)
          data.try &.to_json
        end

        def self.load(data)
          Hash(String, String | UploadedFile::MetadataType).from_json(data)
        end
      end

      DEFAULT_OPTIONS = {
        column_serializer: Shrine::Plugins::Column::JsonSerializer,
      }

      module AttacherClassMethods
        # Initializes the attacher from a data hash/string expected to come
        # from a database record column.
        #
        #     Attacher.from_column('{"id":"...","storage":"...","metadata":{...}}')
        def from_column(data, **options) : Attacher | Nil
          attacher = new(**options)
          attacher.load_column(data)
          attacher
        end
      end

      module AttacherMethods
        # Column serializer object.
        getter column_serializer : Shrine::Plugins::Column::BaseSerializer.class

        # Allows overriding the default column serializer.
        def initialize(@column_serializer = self.class.shrine_class.plugin_settings.column[:column_serializer], **options)
          super(**options)
        end

        # Loads attachment from column data.
        #
        #     attacher.file #=> nil
        #     attacher.load_column('{"id":"...","storage":"...","metadata":{...}}')
        #     attacher.file #=> #<Shrine::UploadedFile>
        def load_column(data : String) : UploadedFile
          load_data(column_serializer.load(data))
        end

        def load_column(data : Nil) : Nil
          load_data(data)
        end

        # Returns attacher data as a serialized string (JSON by default).
        #
        #     attacher.column_data #=> '{"id":"...","storage":"...","metadata":{...}}'
        def column_data : String | Nil
          column_serializer.dump(data)
        end
      end
    end
  end
end
