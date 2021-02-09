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

require 'rails_helper'
require 'fileutils'

TEMPFILE_NAME = File.join(Rails.root, 'tmp', 'document_spec', 'test.txt')

RSpec.describe Document, type: :model do
  it { is_expected.to belong_to(:external_user) }
  it { is_expected.to belong_to(:creator).class_name('ExternalUser') }
  it { is_expected.to belong_to(:claim) }
  it { is_expected.to delegate_method(:provider_id).to(:external_user) }

  it { is_expected.to have_one_attached :document }
  it { is_expected.to validate_presence_of :document }

  it { is_expected.to have_one_attached :converted_preview_document }
  it { is_expected.to validate_content_type_of(:converted_preview_document).allowing('application/pdf') }

  it_behaves_like 'an s3 bucket'

  it do
    is_expected.to validate_content_type_of(:document)
      .allowing(
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
      ).rejecting('text/plain', 'text/html')
  end

  it { should validate_size_of(:document).less_than_or_equal_to(20.megabytes) }

  context 'validation' do
    let(:claim) { create :claim }
    let(:document) { create :document, claim: claim }

    context 'total number of documents for this form_id' do
      it 'validates that the total number of documents for this claim has not been exceeded' do
        allow(Settings).to receive(:max_document_upload_count).and_return(2)
        create :document, claim_id: claim.id, form_id: claim.form_id
        create :document, claim_id: claim.id, form_id: claim.form_id

        doc = build :document, claim_id: claim.id, form_id: claim.form_id
        expect(doc).not_to be_valid
        expect(doc.errors[:document]).to eq(['Total documents exceed maximum of 2. This document has not been uploaded.'])
      end
    end
  end

  describe '#save!' do
    subject(:document_save) { document.save! }

    let(:document) { build(:document, :docx, document_content_type: 'application/msword') }

    before { ActiveJob::Base.queue_adapter = :test }

    it 'schedules a CreateDocumentPreviewJob for the document' do
      expect { document_save }
        .to have_enqueued_job(CreateDocumentPreviewJob)
        .with(document.to_param)
    end
  end

  describe '#save_and_verify' do
    subject(:save_and_verify) { document.save_and_verify }
    let(:document) { build :document }

    it 'marks the document as verified' do
      # With Active Storage (for the moment) verified will always be true
      # TODO: Either remove verified or implement a verification check
      expect { save_and_verify }.to change(document, :verified).from(false).to true
    end

    it 'copies the file name to #document_file_name' do
      # For backward compatibility with Paperclip.
      expect { save_and_verify }.to change(document, :document_file_name).to document.document.filename
    end

    it 'copies the byte size to #document_file_size' do
      # For backward compatibility with Paperclip.
      expect { save_and_verify }.to change(document, :document_file_size).to document.document.byte_size
    end
  end

  describe '#copy_from' do
    subject(:copy_file) { new_document.copy_from old_document }

    let(:verified) { true }
    let(:trait) { :with_preview }
    let(:old_document) { create :document, trait, verified: verified }
    let(:new_document) { build(:document, :empty) }

    it 'copies the document from the old document' do
      copy_file
      expect(new_document.document.checksum).to eq old_document.document.checksum
    end

    it 'copies the document filename from the old document' do
      copy_file
      expect(new_document.document.filename).to eq old_document.document.filename
    end

    context 'when the document preview exists' do
      before { copy_file }

      it 'copies the document preview from the old document' do
        expect(new_document.converted_preview_document.checksum)
          .to eq old_document.converted_preview_document.checksum
      end

      it 'copies the document preview filename from the old document' do
        expect(new_document.converted_preview_document.filename)
          .to eq old_document.converted_preview_document.filename
      end
    end

    context 'when the document preview does not exist' do
      let(:trait) { :docx }

      before { ActiveJob::Base.queue_adapter = :test }

      it 'schedules a CreateDocumentPreviewJob for the document' do
        old_document # Preload old document to avoid two jobs being enqueued
        expect { copy_file }
          .to have_enqueued_job(CreateDocumentPreviewJob)
          .with(new_document.to_param)
      end
    end

    context 'when the document is verified' do
      before { copy_file }

      it 'sets the new document as verified' do
        expect(new_document.verified).to be_truthy
      end
    end

    context 'when the document is not verified' do
      before { copy_file }

      let(:verified) { false }

      it 'sets the new document as not verified' do
        expect(new_document.verified).to be_falsey
      end
    end
  end

  describe '#convert_document!' do
    subject(:convert_document) { document.convert_document! }

    before do
      allow(Libreconv).to receive(:convert) do |_original, output|
        File.open(File.expand_path('features/examples/shorter_lorem.pdf', Rails.root), 'rb') do |input|
          IO.copy_stream(input, output)
        end
        output.rewind
      end
    end

    context 'with a pdf file' do
      let(:document) { build :document }

      before { convert_document }

      it 'attaches the document as the converted preview document' do
        expect(document.converted_preview_document.blob)
          .to eq document.document.blob
      end
    end

    context 'with a docx file' do
      let(:document) { create :document, :docx }

      before { convert_document }

      it 'creates a converted file with content type application/pdf' do
        expect(document.converted_preview_document.content_type)
          .to eq 'application/pdf'
      end

      it 'appends .pdf to the filename for the converted file' do
        expect(document.converted_preview_document.filename)
          .to eq "#{document.document.filename}.pdf"
      end
    end

    context 'when Libreconv is not in PATH' do
      let(:document) { create :document, :docx }

      before { allow(Libreconv).to receive(:convert).and_raise(IOError) }

      it 'raises and error to retry the job' do
        expect { convert_document }.to raise_error(DocumentAttachment::LibreconfFailed)
      end
    end
  end
end
