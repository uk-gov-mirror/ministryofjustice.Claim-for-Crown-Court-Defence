require "rails_helper"

RSpec.describe GovukDesignSystemHelper do
  describe '#govuk_link' do

    context '#govuk-back-link' do

      subject(:link) do
        helper.govuk_link('My link text', '#', 'govuk-back-link')
      end

      it 'sets link body' do
        expect(link).to include 'My link text'
      end

      it 'sets link class' do
        expect(link).to include 'class="govuk-back-link"'
      end

      it 'sets link href' do
        expect(link).to include 'href="#"'
      end
    end
  end
end
