require "rails_helper"


describe ClaimsHelper do

  describe '#claim_allocation_checkbox_helper' do
    let(:case_worker)         { double CaseWorker }
    let(:claim)               { double Claim }

    before(:each) do
      allow(claim).to receive(:id).and_return(66)
      allow(case_worker).to receive(:id).and_return(888)
    end

    it 'should produce the html for a checked checkbox if the claim is allocated to the case worker' do
      expect(claim).to receive(:is_allocated_to_case_worker?).with(case_worker).and_return(true)
      expected_html = %q{<input checked="checked" id="case_worker_claim_ids_66" name="case_worker[claim_ids][]" type="checkbox" value="66">}
      expect(claim_allocation_checkbox_helper(claim, case_worker)).to eq expected_html
    end

    it 'should produce the html for a un-checked checkbox if the claim is not allocated to the case worker' do
      expect(claim).to receive(:is_allocated_to_case_worker?).with(case_worker).and_return(false)
      expected_html = %q{<input  id="case_worker_claim_ids_66" name="case_worker[claim_ids][]" type="checkbox" value="66">}
      expect(claim_allocation_checkbox_helper(claim, case_worker)).to eq expected_html
    end

  end

	describe "#includes_state?" do

		let(:only_allocated_claims) { create_list(:allocated_claim, 5) }

		it "returns true if state included as array" do
			states_as_arr = ['draft','allocated']
			expect(includes_state?(only_allocated_claims,states_as_arr)).to eql(true)
		end

		it "returns true if state included as comma delimited string" do
			states_as_comma_delimited_string='draft,allocated'
			expect(includes_state?(only_allocated_claims,states_as_comma_delimited_string)).to eql(true)
		end

		it "returns false if state NOT included" do
			invalid_states ='draft,submitted'
			expect(includes_state?(only_allocated_claims,invalid_states)).to eql(false)
		end

	end


	describe '#number_with_precision_or_blank' do

		it 'should return empty string if given integer zero and no precision' do
			expect(helper.number_with_precision_or_blank(0)).to eq ''
		end

		it 'should return empty string if given integer zero and precision' do
			expect(helper.number_with_precision_or_blank(0, precision: 2)).to eq ''
		end

		it 'should return empty string if given BigDecimal zero' do
			expect(helper.number_with_precision_or_blank(BigDecimal.new(0,5))).to eq ''
		end

		it 'should return empty string if given Float zero' do
			expect(helper.number_with_precision_or_blank(0.0, precision: 2)).to eq ''
		end

		it 'should return 3.33 if given 3.3333 with precsion 2' do
			expect(helper.number_with_precision_or_blank(3.333, precision: 2)).to eq '3.33'
		end

		it 'should return 24.5 if given 24.5 with no precision' do
			expect(helper.number_with_precision_or_blank(24.5)).to eq '24.5'
		end

		it 'should return 4 if given 3.645 with precsion 0' do
			expect(helper.number_with_precision_or_blank(3.645, precision: 0)).to eq '4'
		end
	end

end