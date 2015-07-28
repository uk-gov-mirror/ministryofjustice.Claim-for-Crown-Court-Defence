# == Schema Information
#
# Table name: vat_rates
#
#  id               :integer          not null, primary key
#  rate_base_points :integer
#  effective_date   :date
#  created_at       :datetime
#  updated_at       :datetime
#




# Class to return the vat rate in base points (i.e. 1750 = a vat rate of 17.5%).
# All rates are cached in a class variable on first use to prevent re-reading the vat_rates table 
# every time.
#
class VatRate < ActiveRecord::Base

  class MissingVatRateError < RuntimeError;end

  validate :effective_date, uniqueness: true

  @@rates = nil

  def self.instantiate_rates
    @@rates = VatRate.all.order('effective_date DESC')
  end


  def self.for_date(date)
    instantiate_rates if @@rates.nil?
    rate_for_date(date)
  end


  def self.rate_for_date(date)
    result = nil
    @@rates.each do | rec |
      unless date < rec.effective_date
        result = rec
        break
      end
    end
    raise ::VatRate::MissingVatRateError.new("There is no VAT rate for date #{date.strftime(Settings.date_format)}") if result.nil?
    result.rate_base_points
  end

  private_class_method :rate_for_date

end
