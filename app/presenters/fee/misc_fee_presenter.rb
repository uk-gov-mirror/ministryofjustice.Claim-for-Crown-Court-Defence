class Fee::MiscFeePresenter < Fee::BaseFeePresenter
  def quantity
    agfs? ? super : not_applicable
  end

  def rate
    agfs? ? super : not_applicable
  end

  def days_claimed
    super
  end

  def vat_amount
    h.number_to_currency VatRate.vat_amount(claim.misc_fees_total, claim.vat_date, calculate: claim.apply_vat?)
  end

  private

  def agfs?
    fee&.claim&.agfs? ? true : false
  end
end
