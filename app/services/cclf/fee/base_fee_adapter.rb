module CCLF
  module Fee
    class BaseFeeAdapter
      KEYS = %i[bill_type bill_subtype bill_scenario].freeze

      attr_reader :object
      attr_reader :mappings

      delegate :bill_type, :bill_subtype, :bill_scenario, to: :@bill_types

      def self.zip(bill_types = [])
        Hash[KEYS.zip(bill_types)]
      end

      def initialize(object)
        @object = object
        @mappings = bill_mappings
        @bill_types = OpenStruct.new(mappings[bill_key])
      end

      def maps?
        bill_type.present?
      end

      private

      def bill_mappings
        raise 'Implement in sub-class'
      end

      def bill_key
        raise 'Implement in sub-class'
      end

      # delegate missing methods to object if it can respond
      def method_missing(method, *args, &block)
        if object.respond_to?(method)
          object.send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        object.respond_to?(method) || super
      end
    end
  end
end
