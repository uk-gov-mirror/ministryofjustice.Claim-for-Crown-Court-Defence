# Shared validators for fees requiring additional case numbers
# namely, BANOC and FXNOC (AGFS) and MIXUPL (LGFS).
#
# Any fee type that requires this validaiton should implement
# a case_uplift? method that returns true for the specific fee
# requiring the validation.
#
module Fee
  module Concerns
    module CaseNumbersValidator
      CASE_NUMBER_PATTERN = BaseValidator::CASE_NUMBER_PATTERN

      private

      # TODO: At time of writing the AGFS case uplift fee types are
      # not requiring case numbers due to impact on the API
      # but this SHOULD change for CCR compatability.
      #

      delegate :case_uplift?, :case_numbers, :quantity, :fee_type, :claim, to: :@record

      def validate_case_numbers
        return if fee_type&.unique_code.nil?

        if case_uplift?
          validate_case_numbers_presence
          validate_case_numbers_quantity_mismatch if claim.agfs?
        else
          validate_absence(:case_numbers, 'present')
        end
      end

      # TODO: on or after 1st April 2018 the API should also enforce presence
      def validate_case_numbers_presence
        validate_presence(:case_numbers, 'blank') if claim.lgfs?
        validate_presence(:case_numbers, 'blank') if [claim.agfs?, quantity.to_i.positive?, !claim&.api_draft?].all?
      end

      def validate_case_numbers_quantity_mismatch
        return if case_numbers.blank?
        add_error(:case_numbers, 'noc_qty_mismatch') if case_numbers.split(',').size != quantity
      end
    end
  end
end
