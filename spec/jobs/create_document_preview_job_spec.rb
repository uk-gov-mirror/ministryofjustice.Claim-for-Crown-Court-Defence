require 'rails_helper'

RSpec.describe CreateDocumentPreviewJob, type: :job do
  let(:job) { described_class.new }

  describe '#preform' do
    subject(:perform) { job.perform(document.to_param) }

    before do
      allow(Document).to receive(:find).with(document.id.to_s).and_return(document)
      allow(document).to receive(:convert_document!)
    end

    context 'with an existing document preview' do
      let(:document) { create :document, :with_preview }

      it 'does not call Document#convert_document!' do
        perform
        expect(document).not_to have_received(:convert_document!)
      end
    end

    context 'without an existing document preview' do
      let(:document) { create :document, :docx }

      it 'calls Document#convert_document!' do
        perform
        expect(document).to have_received(:convert_document!)
      end
    end
  end
end