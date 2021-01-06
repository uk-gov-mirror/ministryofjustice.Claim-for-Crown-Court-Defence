RSpec.shared_examples 'active storage migration for' do |asset|
  context 'with an attached asset' do
    let(:factory_name) { described_class.to_s.downcase.to_sym }
    let(:file) { File.open(Rails.root + 'features/examples/shorter_lorem.docx') }
    let(:sample_instance) { create factory_name, asset => file }
    subject(:attachment_creation) { sample_instance.convert_to_active_storage(asset) }

    describe '.convert_to_active_storage' do
      it 'creates a new ActiveStorage::Attachment' do
        expect { attachment_creation }.to change(ActiveStorage::Attachment, :count).by 1
      end

      it 'creates a new ActiveStorage::Blob' do
        expect { attachment_creation }.to change(ActiveStorage::Blob, :count).by 1
      end

      context 'when attachment created correctly' do
        let(:paperclip_attachment) { sample_instance.send asset }
        let(:active_storage_attachment) { ActiveStorage::Attachment.last }
        let(:active_storage_blob) { active_storage_attachment.blob }

        before { attachment_creation }

        it 'attaches correctly to the original record' do
          expect(active_storage_attachment.record).to eq sample_instance
        end

        it 'sets the asset name in the active storage attachment' do
          expect(active_storage_attachment.name).to eq asset.to_s
        end

        it 'copies the file name to the active storage blob' do
          expect(active_storage_blob.filename).to eq sample_instance.send("#{asset}_file_name")
        end

        it 'copies the file size to the active storage blob' do
          expect(active_storage_blob.byte_size).to eq file.size
        end
      end
    end
  end

  context 'without an attached asset' do
    let(:sample_instance) { described_class.new }
    subject(:attachment_creation) { sample_instance.convert_to_active_storage(asset) }
  
    describe '.convert_to_active_storage' do
      it 'does not create a new ActiveStorage::Attachment' do
        expect { attachment_creation }.not_to change(ActiveStorage::Attachment, :count)
      end

      it 'does not create a new ActiveStorage::Blob' do
        expect { attachment_creation }.not_to change(ActiveStorage::Blob, :count)
      end
    end
  end
end
