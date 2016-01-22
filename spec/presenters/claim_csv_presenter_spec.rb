require 'rails_helper'

RSpec.describe ClaimCsvPresenter do

  let(:claim)               { create(:redetermination_claim) }
  let(:subject)             { ClaimCsvPresenter.new(claim, view) }

  context '#present!' do

    context 'generates a line of CSV for each time a claim passes through the system' do

      context 'with identical values for' do

        it 'case_number' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include(claim.case_number)
            expect(claim_journeys.second).to include(claim.case_number)
          end
        end

        it 'account number' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include(claim.external_user.supplier_number)
            expect(claim_journeys.second).to include(claim.external_user.supplier_number)
          end
        end

        it 'organistion/provider_name' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include(claim.external_user.provider.name)
            expect(claim_journeys.second).to include(claim.external_user.provider.name)
          end
        end

        it 'case_type' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include(claim.case_type.name)
            expect(claim_journeys.second).to include(claim.case_type.name)
          end
        end

        it 'total (ex VAT)' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include(claim.total.to_s)
            expect(claim_journeys.second).to include(claim.total.to_s)
          end
        end

      end

      context 'and unique values for' do

        it 'submission type' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include('new')
            expect(claim_journeys.second).to include('redetermination')
          end
        end

        it 'date submitted' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include((Time.now - 3.day).to_s)
            expect(claim_journeys.second).to include((Time.now).to_s)
          end
        end

        it 'date allocated' do      
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include((Time.now - 2.day).to_s)
            expect(claim_journeys.second).to include('n/a', 'n/a')
          end
        end

        it 'date of last assessment' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include((Time.now - 1.day).to_s)
            expect(claim_journeys.second).to include('n/a', 'n/a')
          end
        end

        it 'current/end state' do
          subject.present! do |claim_journeys|
            expect(claim_journeys.first).to include('authorised')
            expect(claim_journeys.second).to include('redetermination')
          end
        end

      end
    end
  end
end
