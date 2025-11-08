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

describe "Shrine.plugin" do
  describe NonPluginUploader do
    it "responds to .foo with \"foo\"" do
      NonPluginUploader.responds_to?(:foo).should be_true
      NonPluginUploader.foo.should eq "foo"
    end

    it "responds to #foo with \"foo\"" do
      uploader = NonPluginUploader.new("store")
      uploader.responds_to?(:foo).should be_true
      uploader.foo.should eq "foo"
    end
  end

  describe PluginUploader do
    it "overrides .foo and #foo with plugin_foo" do
      PluginUploader.responds_to?(:foo).should be_true
      PluginUploader.foo.should eq "plugin_foo"

      uploader = PluginUploader.new("store")
      uploader.responds_to?(:foo).should be_true
      uploader.foo.should eq "plugin_foo"
    end
  end

  describe PluginUploader::UploadedFile do
    it "adds foo to UploadedFile subclass only" do
      PluginUploader::UploadedFile.responds_to?(:foo).should be_true
      PluginUploader::UploadedFile.foo.should eq "plugin_foo"

      Shrine::UploadedFile.responds_to?(:foo).should be_false
    end
  end

  describe "Plugin settings" do
    it "exposes plugin_settings with all plugins" do
      settings = PluginUploader.plugin_settings
      all = settings.all
      all.size.should be > 0
      all.any? { |plugin| plugin[:name] == "foo_plugin" }.should be_true
    end

    it "provides accessor for each plugin" do
      settings = PluginUploader.plugin_settings
      settings.responds_to?(:foo_plugin).should be_true
      settings.foo_plugin.should be_nil
    end
  end
end
