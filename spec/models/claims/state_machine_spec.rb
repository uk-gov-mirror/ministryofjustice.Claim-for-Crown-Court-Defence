require 'rails_helper'

RSpec.describe Claims::StateMachine, type: :model do
  subject { create(:claim) }

  describe 'all available states' do
    let(:states) do
      [:allocated, :archived_pending_delete, :awaiting_further_info, :awaiting_info_from_court, :completed,
       :deleted, :draft, :paid, :part_paid, :refused, :rejected, :submitted, :redetermination]
    end

    it('exist')       { expect(Claim.state_machine.states.map(&:name).sort).to eq(states.sort) }
    it('are valid')   { states.each { |s| subject.state = s; expect(subject).to be_valid } }
  end

  describe 'valid transitions' do
    describe 'from redetermination' do
      before { subject.submit! }

      it { expect{ subject.allocate! }.to change{ subject.state }.to('allocated') }
    end

    describe 'from allocated' do
      before { subject.submit!; subject.allocate! }
      it { expect{ subject.reject! }.to                 change{ subject.state }.to('rejected') }
      it { expect{ subject.submit! }.to                 change{ subject.state }.to('submitted') }
      it { allow(subject).to receive(:complete!);       expect{ subject.refuse! }.to change{ subject.state }.to('refused') }
      it {
        expect{ subject.update_attribute(:amount_assessed, 123.45)
        subject.pay_part!
      }.to change{ subject.state }.to('part_paid') }
      it { expect{
        subject.update_attribute(:amount_assessed, 123.45)
        subject.pay!
      }.to change{ subject.state }.to('paid') }
      it { expect{ subject.await_info_from_court! }.to  change{ subject.state }.to('awaiting_info_from_court') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from awaiting_further_info when part_paid' do
      before {
        subject.submit!
        subject.allocate!
        subject.update_attribute(:amount_assessed, 123.45)
        subject.pay_part!
        subject.await_further_info!
      }
      it { expect{ subject.complete! }.to change{ subject.state }.to('completed') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from awaiting_further_info_from_court' do
      before { subject.submit!; subject.allocate!; subject.await_info_from_court! }
      it { expect{ subject.allocate! }.to change{ subject.state }.to('allocated') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from draft' do
      it { expect{ subject.submit! }.to change{ subject.state }.to('submitted') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from paid' do
      before {
        subject.submit!
        subject.allocate!
        subject.update_attribute(:amount_assessed, 123.45)
        subject.pay!
      }
      it { expect{ subject.complete! }.to change{ subject.state }.to('completed') }
      it { expect{ subject.redetermine! }.to change{ subject.state }.to('redetermination') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from part_paid' do
      before {
        subject.submit!
        subject.allocate!
        subject.update_attribute(:amount_assessed, 123.45)
        subject.pay_part!
      }
      it { expect{ subject.await_further_info! }.to change{ subject.state }.to('awaiting_further_info') }
      it { expect{ subject.redetermine! }.to change{ subject.state }.to('redetermination') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from refused' do
      before { subject.submit!; subject.allocate!; subject.refuse! }
      it { expect{ subject.update_column(:state, 'refused'); subject.complete! }.to change{ subject.state }.to('completed') }
      it { expect{ subject.redetermine! }.to change{ subject.state }.to('redetermination') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from rejected' do
      before { subject.submit!; subject.allocate!; subject.reject! }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end

    describe 'from submitted' do
      before { subject.submit! }
      it { expect{ subject.allocate! }.to change{ subject.state }.to('allocated') }
      it { expect{ subject.archive_pending_delete! }.to change{ subject.state }.to('archived_pending_delete') }
    end
  end # describe 'valid transitions'

  describe 'set triggers' do
    before { Timecop.freeze(Time.now) }
    after  { Timecop.return }

    describe 'make awaiting_further_info valid for 21 days' do
      before {
        subject.submit!
        subject.allocate!
        subject.update_attribute(:amount_assessed, 123.45)
        subject.pay_part!
      }
      it { expect(subject).to receive(:update_column).with(:valid_until, Time.now + 21.days); subject.await_further_info! }
    end

    describe 'make archive_pending_delete valid for 180 days' do
      it { expect(subject).to receive(:update_column).with(:valid_until, Time.now + 180.days); subject.archive_pending_delete! }
    end

    describe 'make submitted_at attribute equal now' do
      it {  expect(subject).to receive(:update_column).with(:submitted_at,Time.now); subject.submit!; }
    end

    describe 'pay! makes paid_at attribute equal now' do
      before { subject.submit!; subject.allocate! }
      it {
        expect(subject).to receive(:update_column).with(:paid_at,Time.now);
        subject.update_attribute(:amount_assessed, 123.45);
        subject.pay!;
      }
    end

    describe 'pay_part! makes paid_at attribute equal now' do
      before { subject.submit!; subject.allocate! }
      it {
        expect(subject).to receive(:update_column).with(:paid_at,Time.now);
        subject.update_attribute(:amount_assessed, 123.45);
        subject.pay_part!;
      }
    end
  end # describe 'set triggers'


  describe '.is_in_state?' do
    let(:claim)         { build :unpersisted_claim }

    it 'should be true if state is in ADVOCATE_DASHBOARD_SUBMITTED_STATES' do
      allow(claim).to receive(:state).and_return('allocated')
      expect(Claims::StateMachine.is_in_state?(:advocate_dashboard_submitted?, claim)).to be true
    end

    it 'should return false if the state is not one of the ADVOCATE_DASHBOARD_SUBMITTED_STATES' do
      allow(claim).to receive(:state).and_return('draft')
      expect(Claims::StateMachine.is_in_state?(:advocate_dashboard_submitted?, claim)).to be false
    end

    it 'should return false if the method name is not recognised' do
      allow(claim).to receive(:state).and_return('draft')
      expect(Claims::StateMachine.is_in_state?(:advocate_rubbish_submitted?, claim)).to be false
    end
  end

  describe 'state transition audit trail' do
    let!(:claim) { create(:claim) }
    let!(:expected) do
      {
        event: 'submit',
        from: 'draft',
        to: 'submitted'
      }
    end

    it 'should log state transitions' do
      expect { claim.submit! }.to change(ClaimStateTransition, :count).by(1)
    end

    it 'the log transition should reflect the state transition/change' do
      claim.submit!
      expect(ClaimStateTransition.last.event).to eq(expected[:event])
      expect(ClaimStateTransition.last.from).to eq(expected[:from])
      expect(ClaimStateTransition.last.to).to eq(expected[:to])
    end
  end
end
