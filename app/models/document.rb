# == Schema Information
#
# Table name: documents
#
#  id                                      :integer          not null, primary key
#  claim_id                                :integer
#  created_at                              :datetime
#  updated_at                              :datetime
#  document_file_name                      :string
#  document_content_type                   :string
#  document_file_size                      :integer
#  document_updated_at                     :datetime
#  external_user_id                        :integer
#  converted_preview_document_file_name    :string
#  converted_preview_document_content_type :string
#  converted_preview_document_file_size    :integer
#  converted_preview_document_updated_at   :datetime
#  uuid                                    :uuid
#  form_id                                 :string
#  creator_id                              :integer
#  verified_file_size                      :integer
#  file_path                               :string
#  verified                                :boolean          default(FALSE)
#

class Document < ApplicationRecord
  include Duplicable
  include PaperclipRollback

  belongs_to :external_user
  belongs_to :creator, class_name: 'ExternalUser'
  belongs_to :claim, class_name: 'Claim::BaseClaim'

  has_one_attached :converted_preview_document
  has_one_attached :document

  validate :documents_count
  validates :converted_preview_document, content_type: 'application/pdf'
  validates :document,
            presence: true,
            size: { less_than: 20.megabytes },
            content_type: %w[
              application/pdf
              application/msword
              application/vnd.openxmlformats-officedocument.wordprocessingml.document
              application/vnd.oasis.opendocument.text
              text/rtf
              application/rtf
              image/jpeg
              image/png
              image/tiff
              image/bmp
              image/x-bitmap
            ]

  alias attachment document # to have a consistent interface to both Document and Message
  delegate :provider_id, to: :external_user

  before_create -> { populate_paperclip_for :document }
  after_create :convert_document

  before_destroy :purge_attachments

  def copy_from(original)
    document.attach(original.document.blob)
    if original.converted_preview_document.attached?
      converted_preview_document.attach(original.converted_preview_document.blob)
    end
    self.verified = original.verified
  end

  def save_and_verify
    # For backward compatiblity
    # Previously there was a step that marked documents as 'verified' and only these documents are visible to the user.
    # Therefore this flag needs to be set or the documents will not appear. The scope in BaseClaim in the
    # `has_many :documents` clause cannot be remove or documents that were previously marked as unverified would begin
    # to appear. Over time, however, the number of these documents will be reduced and so this field can be removed.
    self.verified = true
    save
  rescue ActiveSupport::MessageVerifier::InvalidSignature => e
    # This is to replecate old Paperclip behavour. The controller tests attempted to submit with an empty string instead
    # of a file upload. This should never happen unless the front-end is broken.
    errors.add(:base, e.message)
    self.verified = false
  end

  private

  def documents_count
    return true if form_id.nil?
    count = Document.where(form_id: form_id).count
    max_doc_count = Settings.max_document_upload_count
    return unless count >= max_doc_count
    errors.add(:document, "Total documents exceed maximum of #{max_doc_count}. This document has not been uploaded.")
  end

  def convert_document
    ConvertDocumentJob.set(wait: 30.seconds).perform_later(to_param)
  end

  def purge_attachments
    document.purge
    converted_preview_document.purge
  end
end
