require "../spec_helper"

module FooPlugin
  module ClassMethods;    def foo; "plugin_foo"; end; end
  module InstanceMethods; def foo; "plugin_foo"; end; end
end

class NonPluginUploader < Shrine
  def foo; "foo"; end;
  def self.foo; "foo"; end;
end

class PluginUploader < Shrine
  load_plugin ::FooPlugin
  create_plugins_class_method
end

Spectator.describe "Shrine.plugin" do

end