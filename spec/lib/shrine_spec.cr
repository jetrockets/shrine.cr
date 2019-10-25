require "../spec_helper"

Spectator.describe Shrine do
  describe "logger" do
    it "responds_to `logger`" do
      expect(Shrine).to respond_to(:logger)
    end

    it "sets default log_level to WARN" do
      expect(Shrine.settings.log_level).to eq(Logger::WARN)
      expect(Shrine.logger.level).to eq(Logger::WARN)
    end
  end
end