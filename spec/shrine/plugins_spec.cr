require "../spec_helper"

module FooPlugin
  module ClassMethods
    def foo
      "plugin_foo"
    end
  end

  module InstanceMethods
    def foo
      "plugin_foo"
    end
  end

  module FileClassMethods
    def foo
      "plugin_foo"
    end
  end

  module FileMethods
    def foo
      "plugin_foo"
    end
  end
end

class NonPluginUploader < Shrine
  module ClassMethods
    def foo
      "foo"
    end
  end

  module InstanceMethods
    def foo
      "foo"
    end
  end

  extend ClassMethods
  include InstanceMethods
end

class PluginUploader < NonPluginUploader
  load_plugin ::FooPlugin
  finalize_plugins!
end

Spectator.describe "Shrine.plugin" do
  describe "NonPluginUploader" do
    let(uploader) { NonPluginUploader }
    let(uploader_instance) { uploader.new("store") }

    it "responds to .foo with \"foo\"" do
      expect(uploader).to respond_to("foo")
      expect(uploader.foo).to eq("foo")
    end

    it "responds to #foo with \"foo\"" do
      expect(uploader_instance).to respond_to("foo")
      expect(uploader_instance.foo).to eq("foo")
    end
  end

  describe "PluginUploader" do
    let(uploader) { PluginUploader }
    let(uploader_instance) { uploader.new("store") }

    it "responds to .foo with \"foo\"" do
      expect(uploader).to respond_to("foo")
      expect(uploader.foo).to eq("plugin_foo")
    end

    it "responds to #foo with \"foo\"" do
      expect(uploader_instance).to respond_to("foo")
      expect(uploader_instance.foo).to eq("plugin_foo")
    end
  end

  describe "PluginUploader::UploadedFile" do
    let(superclass_file) { Shrine::UploadedFile }
    let(uploaded_file) { PluginUploader::UploadedFile }

    it "responds to .foo with \"foo\"" do
      expect(uploaded_file).to respond_to("foo")
      expect(uploaded_file.foo).to eq("plugin_foo")

      # expect(Shrine::UploadedFile.new).to be_true
    end

    it "does not pollute superclass" do
      expect(superclass_file).not_to respond_to("foo")
    end
  end
end
