module DocumentAttachment
  extend ActiveSupport::Concern
  include S3Headers

  included do
    attr_accessor :pdf_tmpfile

    has_one_attached :converted_preview_document
    has_one_attached :document

    before_save :copy_file_name

    validates :converted_preview_document, content_type: 'application/pdf'
    validates :document,
              presence: true,
              size: { less_than: 20.megabytes },
              content_type: [
                'application/pdf',
                'application/msword',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                'application/vnd.oasis.opendocument.text',
                'text/rtf',
                'application/rtf',
                'image/jpeg',
                'image/png',
                'image/tiff',
                'image/bmp',
                'image/x-bitmap'
              ]
  end

  def create_preview_document
    if document.content_type == 'application/pdf'
      self.converted_preview_document = document.blob
    else
      convert_document_to_pdf
    end
  end

  def convert_document!
    if document.content_type == 'application/pdf'
      converted_preview_document.attach document.blob
    else
      convert_document_to_pdf
    end
  end

  private

  def convert_document_to_pdf
    document.open do |file|
      pdf_tmpfile = Tempfile.new
      Libreconv.convert(file.path, pdf_tmpfile)
      converted_preview_document.attach(
        io: pdf_tmpfile,
        filename: "#{document.filename}.pdf",
        content_type: 'application/pdf'
      )
    end
  rescue IOError
    # TODO: What to do with this now?
    nil
  end

  # TODO: Remove this method, which exists for backward compatibility with Paperclip
  def copy_file_name
    if document.attached?
      self.document_file_name = document.filename.to_s
      self.document_file_size = document.byte_size
    end
    if converted_preview_document.attached?
      self.converted_preview_document_file_name = converted_preview_document.filename.to_s
      self.converted_preview_document_file_size = converted_preview_document.byte_size
    end
  end
end
