class CreateDocumentPreviewJob < ApplicationJob
  queue_as :document_preview

  retry_on Document::LibreconfFailed

  def perform(document_id)
    document = Document.find(document_id)

    document.convert_document! unless document.converted_preview_document.attached?
  end
end