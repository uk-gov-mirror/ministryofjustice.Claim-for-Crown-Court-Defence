require 'rails_helper'
require_relative 'shared_examples_for_claim_presenters'

RSpec.describe Claim::LitigatorHardshipClaimPresenter, type: :presenter do
  subject(:presenter) { described_class.new(claim, view) }

  let(:claim) { create(:litigator_hardship_claim) }

  it { is_expected.to be_kind_of(Claim::BaseClaimPresenter) }

  describe '#pretty_type' do
    specify { expect(presenter.pretty_type).to eq('LGFS Hardship') }
  end

  describe '#type_identifier' do
    specify { expect(presenter.type_identifier).to eq('lgfs_hardship') }
  end

  describe '#can_have_disbursements?' do
    specify { expect(presenter.can_have_disbursements?).to be_truthy }
  end

  describe '#can_have_expenses?' do
    specify { expect(presenter.can_have_expenses?).to be_truthy }
  end

  describe '#mandatory_case_details?' do
    subject { presenter.mandatory_case_details? }

    context 'when case_type, court, case number and provider details present' do
      before do
        allow(claim).to receive(:case_type).and_return 'a case type'
        allow(claim).to receive(:court).and_return 'a court'
        allow(claim).to receive(:case_number).and_return 'a case number'
        allow(claim).to receive(:external_user).and_return instance_double(ExternalUser)
      end

      it { is_expected.to be_truthy }
    end

    context 'when one of case_type, court, case number and provider details present' do
      before do
        allow(claim).to receive(:case_type).and_return nil
        allow(claim).to receive(:court).and_return 'a court'
        allow(claim).to receive(:case_number).and_return 'a case number'
        allow(claim).to receive(:external_user).and_return instance_double(ExternalUser)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#summary_sections' do
    subject { presenter.summary_sections }

    it {
      is_expected.to eq(
        {
          case_details: :case_details,
          defendants: :defendants,
          offence_details: :offence_details,
          hardship_fee: :hardship_fees,
          misc_fees: :miscellaneous_fees,
          supporting_evidence: :supporting_evidence,
          additional_information: :supporting_evidence
        }
      )
    }
  end

  it {
    is_expected.to respond_to :raw_hardship_fees_total,
                              :raw_hardship_fees_vat,
                              :raw_hardship_fees_gross,
                              :hardship_fees_vat,
                              :hardship_fees_gross,
                              :mandatory_case_details?
  }

  describe '#raw_hardship_fees_total' do
    subject(:raw_hardship_fees_total) { presenter.raw_hardship_fees_total }
    context 'when hardship fee is set' do
      before { create :hardship_fee, claim: claim }

      it { is_expected.to eq 25 }
    end

    context 'when no hardship fee is set' do
      it { is_expected.to eq 0 }
    end
  end

  describe '#raw_hardship_fees_vat' do
    it 'sends message to VatRate' do
      allow(VatRate).to receive(:vat_amount).and_return(20.00)
      presenter.raw_hardship_fees_vat
      expect(VatRate).to have_received(:vat_amount).at_least(:once)
    end
  end

  describe '#raw_hardship_fees_gross' do
    it 'sends message to VatRate' do
      allow(presenter).to receive(:raw_hardship_fees_total).and_return(101.00)
      allow(presenter).to receive(:raw_hardship_fees_vat).and_return(20.20)
      expect(presenter.raw_hardship_fees_gross).to eql 121.20
    end
  end

  describe '#hardship_fees_vat' do
    it 'sends message to VatRate' do
      allow(presenter).to receive(:raw_hardship_fees_vat).and_return(20.20)
      expect(presenter.hardship_fees_vat).to eql '£20.20'
    end
  end

  describe '#hardship_fees_gross' do
    it 'sends message to VatRate' do
      allow(presenter).to receive(:raw_hardship_fees_gross).and_return(101.00)
      expect(presenter.hardship_fees_gross).to eql '£101.00'
    end
  end
end
