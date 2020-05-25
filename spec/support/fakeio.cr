class FakeIO < IO::Memory
  getter :original_filename
  getter :content_type

  def initialize(
    content : String = "",
    filename : String? = nil,
    content_type : String? = nil
  )
    super(content.to_slice, writeable: false)

    @original_filename = filename
    @content_type = content_type
  end
end
