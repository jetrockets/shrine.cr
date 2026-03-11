class Shrine
  module Plugins
    module Column
      # Base serializer with compile-time enforcement
      abstract class BaseSerializer(T)
        # Enforce implementation at compile time
        macro inherited
          \{% if !@type.has_method?(:dump) || !@type.has_method?(:load) %}
            \{% raise "Serializers must implement .dump and .load methods" %}
          \{% end %}
        end

        abstract def self.dump(data : T?) : String?
        abstract def self.load(data : String?) : T?
      end

      # JSON serializer with generic type
      class JsonSerializer(T) < BaseSerializer(T)
        def self.dump(data : T?) : String?
          data.try(&.to_json)
        end

        def self.load(data : String?) : T?
          return nil if data.nil? || data.empty?
          
          begin
            T.from_json(data)
          rescue ex : JSON::ParseException
            raise ArgumentError.new("Invalid JSON data: #{ex.message}")
          end
        end
      end

      # Configuration with type safety
      DEFAULT_OPTIONS = {
        column_serializer: JsonSerializer(Hash(String, JSON::Type)),
        column_name:      "data",
      }

      module AttacherClassMethods
        # Initializes the attacher from a data hash/string expected to come
        # from a database record column.
        #
        # ```
        # attacher = Attacher.from_column('{"id":"...","storage":"...","metadata":{...}}')
        # ```
        def from_column(data : String?, **options) : Attacher?
          return nil if data.nil?
          
          attacher = new(**options)
          attacher.load_column(data)
          attacher
        end
      end

      module AttacherMethods
        # Column serializer with proper type
        getter column_serializer : BaseSerializer(Hash(String, JSON::Type)).class
        
        # Column name in database
        property column_name : String = "data"

        def initialize(
          @column_serializer = self.class.shrine_class.plugin_settings.column[:column_serializer],
          @column_name = self.class.shrine_class.plugin_settings.column[:column_name],
          **options
        )
          super(**options)
        end

        # Loads attachment from column data with validation
        #
        # ```
        # attacher.file #=> nil
        # attacher.load_column('{"id":"...","storage":"...","metadata":{...}}')
        # attacher.file #=> #<Shrine::UploadedFile>
        # ```
        def load_column(data : String) : UploadedFile?
          parsed = column_serializer.load(data)
          return nil if parsed.nil?
          
          # Validate required fields
          unless parsed.has_key?("id") && parsed.has_key?("storage")
            raise ArgumentError.new("Invalid column data: missing 'id' or 'storage'")
          end
          
          load_data(parsed)
        end

        def load_column(data : Nil) : Nil
          load_data(nil)
        end

        # Returns attacher data as a serialized string (JSON by default)
        #
        # ```
        # attacher.column_data #=> '{"id":"...","storage":"...","metadata":{...}}'
        # ```
        def column_data : String?
          column_serializer.dump(data)
        end

        # Helper to get column name for this attacher
        def column_name : String
          @column_name
        end
      end
    end
  end
end

# Convenience method for models
class Shrine::Attacher
  # Store attachment in model's column
  def store_in_model(model)
    model.set_attribute(column_name, column_data)
  end

  # Load attachment from model's column
  def load_from_model(model)
    load_column(model[column_name]?.try(&.to_s))
  end
end