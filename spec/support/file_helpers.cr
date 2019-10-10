require "./fakeio"

module FileHelpers
  def tempfile(content, basename = "")
    tempfile = File.tempfile(basename) do |file|
      file.print(content)
    end

    File.open(tempfile.path)
  end

  def fakeio
    FakeIO.new
  end
end
