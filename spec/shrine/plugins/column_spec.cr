require "../../spec_helper"
require "../../../src/shrine/plugins/column"

class ShrineWithColumn < Shrine
  load_plugin Shrine::Plugins::Column
  finalize_plugins!
end

class ShrineWithColumnCustomSerializer < Shrine
  class CustomSerializer < Shrine::Plugins::Column::BaseSerializer
    def self.dump(data)
      data.try &.to_json
    end

    def self.load(data)
      Hash(String, String | Shrine::UploadedFile::MetadataType).from_json(data)
    end
  end

  load_plugin Shrine::Plugins::Column, column_serializer: CustomSerializer
  finalize_plugins!
end

describe Shrine::Plugins::Column do
  it "BaseSerializer raises when not implemented" do
    expect_raises(NotImplementedError) { Shrine::Plugins::Column::BaseSerializer.dump(nil) }
    expect_raises(NotImplementedError) { Shrine::Plugins::Column::BaseSerializer.load("{}") }
  end

  it "JsonSerializer roundtrips data" do
    data = {"id" => "1", "storage" => "store", "metadata" => Shrine::UploadedFile::MetadataType{"foo" => "bar"}}
    json = Shrine::Plugins::Column::JsonSerializer.dump(data)
    Shrine::Plugins::Column::JsonSerializer.load(json).should eq data
  end

  it "Attacher.load_column loads from JSON" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    attacher = ShrineWithColumn::Attacher.new

    file = Shrine.store(fakeio("data"))
    json = file.data.to_json

    attacher.load_column(json)
    attacher.file!.id.should eq file.id
  end

  it "Attacher.load_column(nil) clears attachment" do
    attacher = ShrineWithColumn::Attacher.new
    attacher.load_column(nil)
    attacher.file.should be_nil
  end

  it "column_data serializes current attachment" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    attacher = ShrineWithColumn::Attacher.new

    file = Shrine.store(fakeio("data"))
    attacher.change(file)

    json = attacher.column_data
    json.should_not be_nil
    Shrine::Plugins::Column::JsonSerializer.load(json) if json
  end

  it "allows custom column serializer" do
    Shrine.settings.storages["store"] = Shrine::Storage::Memory.new
    attacher = ShrineWithColumnCustomSerializer::Attacher.new

    file = Shrine.store(fakeio("data"))
    attacher.change(file)

    json = attacher.column_data
    ShrineWithColumnCustomSerializer::CustomSerializer.load(json).should be_a(Hash(String, String | Shrine::UploadedFile::MetadataType)) if json
  end
end
