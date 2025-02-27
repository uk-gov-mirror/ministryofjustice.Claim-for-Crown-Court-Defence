# == Schema Information
#
# Table name: offences
#
#  id               :integer          not null, primary key
#  description      :string
#  offence_class_id :integer
#  created_at       :datetime
#  updated_at       :datetime
#  unique_code      :string           default("anyoldrubbish"), not null
#

class Offence < ApplicationRecord
  auto_strip_attributes :description, squish: true, nullify: true

  belongs_to :offence_class
  belongs_to :offence_band
  has_many :claims, -> { active }, class_name: 'Claim::BaseClaim', foreign_key: :offence_id, dependent: :nullify
  has_many :offence_fee_schemes, dependent: :destroy
  has_many :fee_schemes, through: :offence_fee_schemes do
    def in_scheme_nine?
      where('version=?', FeeScheme::NINE)
    end
  end

  delegate :offence_category, to: :offence_band, allow_nil: true

  validates :offence_class, presence: true, unless: :offence_band_id
  validates :offence_band, presence: true, unless: :offence_class_id
  validates :description, presence: true
  validates :unique_code, presence: true, uniqueness: true

  validate :offence_class_xor_offence_band

  default_scope { includes(:offence_class).order(:description, :offence_class_id) }

  scope :unique_name, -> { unscoped.in_scheme_nine.select(:description).distinct.order(:description) }
  scope :miscellaneous, -> { where(description: 'Miscellaneous/other') }

  scope :in_scheme_nine, -> { joins(:fee_schemes).merge(FeeScheme.nine).distinct }
  singleton_class.send(:alias_method, :in_scheme_9, :in_scheme_nine)

  scope :in_scheme_ten, -> { joins(:fee_schemes).merge(FeeScheme.ten).distinct }
  singleton_class.send(:alias_method, :in_scheme_10, :in_scheme_ten)

  scope :in_scheme_eleven, -> { joins(:fee_schemes).merge(FeeScheme.eleven).distinct }
  singleton_class.send(:alias_method, :in_scheme_11, :in_scheme_eleven)

  scope :in_scheme_twelve, -> { joins(:fee_schemes).merge(FeeScheme.twelve).distinct }
  singleton_class.send(:alias_method, :in_scheme_12, :in_scheme_twelve)

  def offence_class_description
    offence_class.letter_and_description
  end

  def offence_class_xor_offence_band
    return if offence_class.present? ^ offence_band.present?
    errors[:base] << I18n.t('external_users.claims.offence_details.scheme_xor.one_not_both')
  end

  def scheme_nine?
    fee_schemes.map(&:version).any?(FeeScheme::NINE)
  end

  def scheme_ten?
    fee_schemes.map(&:version).any?(FeeScheme::TEN)
  end

  def scheme_eleven?
    fee_schemes.map(&:version).any?(FeeScheme::ELEVEN)
  end

  def scheme_twelve?
    fee_schemes.map(&:version).any?(FeeScheme::TWELVE)
  end

  def post_agfs_reform?
    fee_schemes.agfs.map(&:version).any? { |s| s > FeeScheme::NINE }
  end
end
