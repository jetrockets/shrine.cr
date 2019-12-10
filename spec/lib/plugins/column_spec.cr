require "../../spec_helper"

require "yaml"

class YamlSerializer < Shrine::Plugins::Column::BaseSerializer
  def self.dump(data)
    data.try &.to_yaml
  end

  def self.load(data)
    Hash(String, String | Shrine::UploadedFile::MetadataType).from_yaml(data)
  end
end

class ShrineWithColumn < Shrine
  load_plugin(Shrine::Plugins::Column)

  finalize_plugins!
end

class ShrineWithColumnAndYamlSerializer < Shrine
  load_plugin(Shrine::Plugins::Column, column_serializer: YamlSerializer)

  finalize_plugins!
end

Spectator.describe Shrine::Plugins::Column do
  include FileHelpers

  let(attacher) {
    ShrineWithColumn::Attacher.new(**NamedTuple.new)
  }

  describe ".from_column" do
    it "loads file from column data" do
      file = attacher.upload(fakeio)
      attacher = ShrineWithColumn::Attacher.from_column(file.to_json)

      expect(attacher.file).to eq(file)
    end

    it "forwards additional options to .new" do
      expect(
        ShrineWithColumn::Attacher.from_column(nil, cache_key: "other_cache").cache_key
      ).to eq("other_cache")
    end
  end

  describe "#initialize" do
    it "accepts a serializer" do
      attacher = ShrineWithColumn::Attacher.new(column_serializer: YamlSerializer)

      expect(attacher.column_serializer).to eq(YamlSerializer)
    end

    it "uses plugin serializer as default" do
      expect(ShrineWithColumnAndYamlSerializer::Attacher.new.column_serializer).to eq(YamlSerializer)
    end
  end

  describe "#load_column" do
    it "loads file from serialized file data" do
      file = attacher.upload(fakeio)
      attacher.load_column(file.to_json)

      expect(attacher.file).to eq(file)
    end

    it "clears file when nil is given" do
      attacher.attach(fakeio)
      attacher.load_column(nil)

      expect(attacher.file).to be_nil
    end

    it "uses custom serializer" do
      attacher = ShrineWithColumn::Attacher.new(column_serializer: YamlSerializer)

      file = attacher.upload(fakeio)
      attacher.load_column(file.data.to_yaml)

      expect(attacher.file).to eq(file)
    end
  end

  describe "#column_data" do
    it "returns serialized file data" do
      attacher.attach(fakeio)

      expect(attacher.column_data).to eq(attacher.file.to_json)
    end

    it "returns nil when no file is attached" do
      expect(attacher.column_data).to be_nil
    end

    it "uses custom serializer" do
      attacher = ShrineWithColumn::Attacher.new(column_serializer: YamlSerializer)
      attacher.attach(fakeio)

      expect(attacher.column_data).to eq(attacher.file.not_nil!.data.to_yaml)
    end
  end
end
