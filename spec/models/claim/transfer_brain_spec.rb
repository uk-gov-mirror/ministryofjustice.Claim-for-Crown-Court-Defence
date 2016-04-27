require 'rails_helper'

module Claim
  describe TransferBrain do
    describe '.transfer_stage_by_id' do

      it 'returns the name of the transfer_stage with that id' do
        expect(TransferBrain.transfer_stage_by_id(50)).to eq 'Transfer before retrial'
      end

      it 'raises if invalid id given' do
        expect{ TransferBrain.transfer_stage_by_id(55) }.to raise_error ArgumentError, 'No such transfer stage id: 55'
      end
    end

    describe '.transfer_stage_id' do
      it 'returns the id of the transfer stage with the given name' do
        expect(TransferBrain.transfer_stage_id('Transfer before retrial')).to eq 50
      end

      it 'raises if no such transfer stage with the given name' do
        expect{ TransferBrain.transfer_stage_id('xxx') }.to raise_error ArgumentError, "No such transfer stage: 'xxx'"
      end
    end

    describe '.transfer_stage_ids' do
      it 'returns transfer stage ids' do
        expect(TransferBrain.transfer_stage_ids).to eq( [ 10, 20, 30, 40, 50, 60, 70 ])
      end
    end

    describe '.case_conclusion_by_id' do
      it 'returns the name of the case conclusion with that id' do
        expect(TransferBrain.case_conclusion_by_id(30)).to eq 'Cracked'
      end

      it 'raises if invalid id given' do
        expect{ TransferBrain.case_conclusion_by_id(55) }.to raise_error ArgumentError, 'No such case conclusion id: 55'
      end
    end

    describe '.case_conclusion_id' do
      it 'returns the id of the case conclusion with the given name' do
        expect(TransferBrain.case_conclusion_id('Retrial')).to eq 20
      end

      it 'raises if no such case conclusion with the given name' do
        expect{ TransferBrain.case_conclusion_id('xxx') }.to raise_error ArgumentError, "No such case conclusion: 'xxx'"
      end
    end

    describe '.details_combo_valid?' do
      it 'returns false for invalid combos' do
        [30, 40, 60, 70].each do |transfer_stage_id|
          detail = transfer_detail('new', true, transfer_stage_id)
          expect(TransferBrain.details_combo_valid?(detail)).to be false
        end
      end

      it 'returns true for visible combos' do
        [ transfer_detail('new', false, 20, 30), transfer_detail('new', false, 30, 20), transfer_detail('new', false, 50, 40) ].each do |detail|
          expect(TransferBrain.details_combo_valid?(detail)).to be true
        end
      end

      it 'returns true for hidden combos' do
        [ transfer_detail('original', false, 70), transfer_detail('original', true, 50), transfer_detail('original', false, 10) ].each do |detail|
          expect(TransferBrain.details_combo_valid?(detail)).to be true
        end
      end


      def transfer_detail(litigator_type, elected_case, transfer_stage_id, case_conclusion_id = 10)
        build :transfer_detail, litigator_type: litigator_type, elected_case: elected_case, transfer_stage_id: transfer_stage_id, case_conclusion_id: case_conclusion_id
      end
    end

    describe '.data_attributes' do
      it 'returns a JSON representation of the data attributes hash' do
        expected_json = File.read(File.join(Rails.root, 'spec', 'data', 'transfer_brain_data_attributes.json')).chomp
        expect(TransferBrain.data_attributes).to eq expected_json
      end
    end
  end


end