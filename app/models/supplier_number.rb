# == Schema Information
#
# Table name: supplier_numbers
#
#  id              :integer          not null, primary key
#  provider_id     :integer
#  supplier_number :string
#

class SupplierNumber < ActiveRecord::Base
  SUPPLIER_NUMBER_REGEX ||= /\A[0-9][a-zA-Z][0-9]{3}[a-zA-Z]\z/

  auto_strip_attributes :supplier_number, squish: true, nullify: true

  belongs_to :provider

  validates :supplier_number, presence: true
  validates :supplier_number, format: { with: SUPPLIER_NUMBER_REGEX, allow_nil: true }
end
