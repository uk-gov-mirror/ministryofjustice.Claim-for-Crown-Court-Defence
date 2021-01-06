module DocumentAttachment
  extend ActiveSupport::Concern
  include S3Headers
  include ActiveStorageMigration

  included do
    attr_accessor :pdf_tmpfile

    if STORAGE_OPTION == :paperclip
      has_attached_file :converted_preview_document, s3_headers.merge(PAPERCLIP_STORAGE_OPTIONS)

      has_attached_file :document, s3_headers.merge(PAPERCLIP_STORAGE_OPTIONS)

      validates_attachment_content_type :converted_preview_document, content_type: 'application/pdf'

      validates_attachment :document,
                           presence: { message: 'Document must have an attachment' },
                           size: { in: 0.megabytes..20.megabytes },
                           content_type: {
                             content_type: ['application/pdf',
                                           'application/msword',
                                           'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                                           'application/vnd.oasis.opendocument.text',
                                           'text/rtf',
                                           'application/rtf',
                                           'image/jpeg',
                                           'image/png',
                                           'image/tiff',
                                           'image/bmp',
                                           'image/x-bitmap']
                           }

    else
      has_one_attached :converted_preview_document
      has_one_attached :document
    end

  end

  def generate_pdf_tmpfile
    if File.extname(document_file_name).casecmp('.pdf').zero?
      self.pdf_tmpfile = document # if original document is PDF, make tmpfile from original doc
    else
      convert_and_assign_document
    end
  end

  def convert_and_assign_document
    # Libreconvert performs both actions in one call
    self.pdf_tmpfile = File.new("#{Dir.mktmpdir}/#{document_file_name}.pdf", 'wb+')
    Libreconv.convert(Paperclip.io_adapters.for(document).path, pdf_tmpfile) # Libreoffice exe must be in PATH
  rescue IOError
    nil # raised if Libreoffice exe is not in PATH
  end

  def add_converted_preview_document
    self.converted_preview_document = pdf_tmpfile if converted_preview_document_file_name.nil?
  end
end
