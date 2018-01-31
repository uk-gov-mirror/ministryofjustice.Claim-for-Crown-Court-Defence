RSpec.shared_examples "common advocate litigator validations" do |external_user_type|

  context 'external_user' do
    it 'should error if not present, regardless' do
      claim.external_user = nil
      should_error_with(claim, :external_user, "blank_#{external_user_type}")
    end

    it 'should error if does not belong to the same provider as the creator' do
      claim.creator = create(:external_user, external_user_type)
      claim.external_user = create(:external_user, external_user_type)
      should_error_with(claim, :external_user, "Creator and #{external_user_type} must belong to the same provider")
    end
  end

  context 'creator' do
    it 'should error if not present, regardless' do
      claim.creator = nil
      should_error_with(claim, :creator, "blank")
    end
  end

  context 'case_type' do
    it 'should error if not present' do
      claim.case_type = nil
      should_error_with(claim, :case_type, "blank")
    end
  end

  context 'court' do
    it 'should error if not present' do
      claim.court = nil
      should_error_with(claim, :court, 'blank')
    end
  end

  context 'transfer_court' do
    before(:each) { claim.transfer_case_number = 'A20161234' }

    it 'should error if blank when a transfer case number is filled' do
      should_error_with(claim, :transfer_court, 'blank')
    end

    it 'should error when the transfer court is the same as the original court' do
      claim.transfer_court = claim.court
      should_error_with(claim, :transfer_court, 'same')
    end
  end

  context 'transfer_case_number' do
    before(:each) { claim.transfer_court = FactoryBot.build(:court) }

    it 'should NOT error if blank' do
      expect(claim.transfer_case_number).to be_blank
      expect(claim).to be_valid
    end

    it 'should error if wrong format' do
      claim.transfer_case_number = 'ABC'
      should_error_with(claim, :transfer_case_number, 'invalid')
    end
  end
end

RSpec.shared_examples "common litigator validations" do

  let(:advocate)      { build(:external_user, :advocate) }
  let(:offence)       { build(:offence) }
  let(:offence_class) { build(:offence_class, class_letter: 'X', description: 'Offences of dishonesty in Class F where the value in is in excess of £100,000') }
  let(:misc_offence)  { create(:offence, description: 'Miscellaneous/other', offence_class: offence_class) }

  describe 'validate creator provider is in LGFS fee scheme' do
    it 'rejects creators whose provider is only agfs' do
      claim.creator = build(:external_user, provider: build(:provider, :agfs))
      expect(claim).not_to be_valid
      expect(claim.errors[:creator]).to eq(["must be from a provider with permission to submit LGFS claims"])
    end

    it 'accepts creators whose provider is only lgfs' do
      claim.creator = create(:external_user, :litigator, provider: build(:provider, :lgfs))
      claim.external_user = claim.creator
      claim.valid?
      expect(claim.errors.key?(:creator)).to be_falsey
      expect(claim.errors.key?(:external_user)).to be_falsey
    end

    it 'accepts creators whose provider is both agfs and lgfs' do
      claim.creator = create(:external_user, :litigator, provider: build(:provider, :agfs_lgfs))
      claim.external_user = claim.creator
      claim.valid?
      expect(claim.errors.key?(:creator)).to be_falsey
      expect(claim.errors.key?(:external_user)).to be_falsey
    end
  end

  context 'case concluded at date' do
    let(:claim) { build :litigator_claim }
    before(:each) { claim.force_validation = true }

    it 'is invalid when absent' do
      should_error_if_not_present(claim,:case_concluded_at,'blank')
    end

    it 'is invalid when too far in past' do
      should_error_if_too_far_in_the_past(claim, :case_concluded_at, 'check_not_too_far_in_past')
    end

    it 'is invalid when in future' do
      should_error_if_in_future(claim, :case_concluded_at, 'check_not_in_future')
    end

    it 'is valid when present' do
      claim.case_concluded_at = 1.month.ago
      expect(claim).to be_valid
      expect(claim.errors.key?(:case_concluded_at)).to be false
    end
  end

  context 'external_user' do
    it 'should error when does not have advocate role' do
      claim.external_user = advocate
      should_error_with(claim, :external_user, "must have litigator role")
    end

    it 'should error if not present, regardless' do
      claim.external_user = nil
      should_error_with(claim, :external_user, "blank_litigator")
    end

    it 'should error if does not belong to the same provider as the creator' do
      claim.creator = create(:external_user, :litigator)
      claim.external_user = create(:external_user, :litigator)
      should_error_with(claim, :external_user, "Creator and litigator must belong to the same provider")
    end
  end

  context 'creator' do
    it 'should error when their provider does not have LGFS role' do
      claim.creator = create(:external_user, :advocate)
      should_error_with(claim, :creator, "must be from a provider with permission to submit LGFS claims")
    end
  end

  context 'advocate_category' do
    it 'should be absent' do
      claim.advocate_category = 'QC'
      should_error_with(claim, :advocate_category, "invalid")
      claim.advocate_category = nil
      expect(claim).to be_valid
    end
  end

  context 'offence' do
    before do
      claim.form_step = 3
      claim.offence = nil
    end

    it 'should error if NOT present for case type without fixed fees' do
      claim.case_type.is_fixed_fee = false
      should_error_with(claim, :offence, 'blank_class')
      claim.case_type.is_fixed_fee = true
      should_not_error(claim, :offence)
    end

    it 'should NOT error if a Miscellaneous/other offence' do
      claim.offence = misc_offence
      expect(claim).to be_valid
    end
  end
end
