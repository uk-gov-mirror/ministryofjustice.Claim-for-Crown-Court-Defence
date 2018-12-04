# Use this service for prices that are determined
# with the supply of multiple unit values.
#
# This includes LGFS (and AGFS?? TODO) graduated fees
#
module Claims
  module FeeCalculator
    class GraduatedPrice < CalculatePrice
      attr_reader :ppe, :days

      private

      def setup(options)
        @fee_type = Fee::BaseFeeType.find(options[:fee_type_id])
        @advocate_category = options[:advocate_category] || claim.advocate_category
        @days = options[:days] || 0
        @ppe = options[:ppe] || 0
      rescue StandardError
        raise 'incomplete'
      end

      def amount
        fee_scheme.calculate do |options|
          options[:scenario] = scenario.id
          options[:offence_class] = offence_class_or_default
          options[:advocate_type] = advocate_type
          options[:fee_type_code] = fee_type_code_for(fee_type)

          options[:day] = days.to_i
          options[:ppe] = ppe.to_i

          # For LGFS graduated fee, transfer fee and interim fee types
          # The number of defendants should be taken from the actual number of
          # defendants and the misc fee defendant uplift removed
          #
          # TODO: retrospectively use actual number of defendants
          # for transfer and graduated fee calc and remove defendant uplift misc fee
          options[:number_of_defendants] = defendants.size if interim?
        end
      end
    end
  end
end
