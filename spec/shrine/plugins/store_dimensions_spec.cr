require "../../spec_helper"

class ShrineWithStoreDimensionsUsingBuiltIn < Shrine
  load_plugin(Shrine::Plugins::StoreDimensions,
    analyzer: Shrine::Plugins::StoreDimensions::Tools::BuiltIn)

  finalize_plugins!
end

class ShrineWithStoreDimensionsUsingPixie < Shrine
  load_plugin(Shrine::Plugins::StoreDimensions,
    analyzer: Shrine::Plugins::StoreDimensions::Tools::Pixie)

  finalize_plugins!
end

Spectator.describe Shrine::Plugins::StoreDimensions do
  include FileHelpers

  describe "built in analyzer" do
    subject { ShrineWithStoreDimensionsUsingBuiltIn }

    it "extracts image dimensions" do
      expect(subject.extract_dimensions(image)).to eq({300, 300})
    end

    it "fails with missing image data" do
      expect_raises(Shrine::Error) do
        subject.extract_dimensions(fakeio)
      end
    end
  end

  describe "pixie analyzer" do
    subject { ShrineWithStoreDimensionsUsingPixie }

    it "extracts image dimensions" do
      expect(subject.extract_dimensions(image)).to eq({300, 300})
    end

    it "fails with missing image data" do
      expect_raises(Shrine::Error) do
        subject.extract_dimensions(fakeio)
      end
    end
  end
end
