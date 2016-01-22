class ClaimTextfieldValidator < BaseClaimValidator

  def self.fields
    [
    :case_type,
    :court,
    :case_number,
    :advocate_category,
    :offence,
    :estimated_trial_length,
    :actual_trial_length,
    :trial_cracked_at_third,
    :total
    ]
  end

  def self.mandatory_fields
    [
    :external_user,
    :creator,
    :amount_assessed,
    :evidence_checklist_ids
    ]
  end

  private

  def validate_total
    unless @record.source == 'api'
      validate_numericality(:total, 0.01, nil, "value claimed must be greater than £0.00")
    end
  end

  # ALWAYS required/mandatory
  def validate_external_user
    validate_presence(:external_user, "blank")
  end

  # ALWAYS required/mandatory
  def validate_creator
    validate_presence(:creator, "blank")
  end

  # must be present
  def validate_case_type
    validate_presence(:case_type, "blank")
  end

  # must be present
  def validate_court
    validate_presence(:court, "blank")
  end

  # must be present
  # must have a format of capital letter followed by 8 digits
  def validate_case_number
    validate_presence(:case_number, "blank")
    validate_pattern(:case_number, /^[A-Z]{1}\d{8}$/, "invalid") unless @record.case_number.blank?
  end

# must be present
# must be one of values in list
def validate_advocate_category
  validate_presence(:advocate_category, "blank")
  validate_inclusion(:advocate_category, Settings.advocate_categories, "Advocate category must be one of those in the provided list") unless @record.advocate_category.blank?
end

def validate_offence
  validate_presence(:offence, "blank") unless fixed_fee_case?
end

# must be present
# must be greater than or eqaul zero
def validate_estimated_trial_length
  if trial_dates_required?
    validate_presence(:estimated_trial_length, "blank")
    validate_numericality(:estimated_trial_length, 1, nil, "invalid") unless @record.estimated_trial_length.nil?
  end
end

# must be present
# must be greater than or equal to zero
def validate_actual_trial_length
  if trial_dates_required?
    validate_presence(:actual_trial_length, "blank")
    validate_numericality(:actual_trial_length, 0, nil, "invalid") unless @record.actual_trial_length.nil?
  end
end

# must be present if case type is cracked trial or cracked before retial
# must be final third if case type is cracked before retrial (cannot be first or second third)
def validate_trial_cracked_at_third
  validate_presence(:trial_cracked_at_third, "blank") if cracked_case?
  validate_pattern(:trial_cracked_at_third, /^final_third$/, "Case cracked in can only be Final Third for trials that cracked before retrial") if (@record.case_type.name == 'Cracked before retrial' rescue false)
end

def validate_amount_assessed
  case @record.state
    when 'authorised', 'part_authorised'
      add_error(:amount_assessed, "Amount assessed cannot be zero for claims in state #{@record.state.humanize}") if @record.assessment.blank?
    when 'draft', 'refused', 'rejected', 'submitted'
      add_error(:amount_assessed, "Amount assessed must be zero for claims in state #{@record.state.humanize}") if @record.assessment.present?
  end
end

def validate_evidence_checklist_ids
  raise ActiveRecord::SerializationTypeMismatch.new("Attribute was supposed to be a Array, but was a #{@record.evidence_checklist_ids.class}.") unless @record.evidence_checklist_ids.is_a?(Array)

  # prevent non-numeric array elements
  # NOTE: non-numeric strings/chars will yield a value of 0 and this is checked for to add an error
  @record.evidence_checklist_ids = @record.evidence_checklist_ids.select(&:present?).map(&:to_i)
  if @record.evidence_checklist_ids.include?(0)
    add_error(:evidence_checklist_ids, "Evidence checklist ids are of an invalid type or zero, please use valid Evidence checklist ids")
    return
  end

  # prevent array elements that do no represent a doctype
  valid_doctype_ids = DocType.all.map(&:id)
  @record.evidence_checklist_ids.each do |id|
    unless valid_doctype_ids.include?(id)
      add_error(:evidence_checklist_ids, "Evidence checklist id #{id} is invalid, please use valid evidence checklist ids")
    end
  end

end


# local helpers
# ---------------------------
# def claim_total
#   @record.fees.map(&:amount).compact.sum + @record.expenses.map(&:amount).compact.sum
# end

def trial_dates_required?
  @record.case_type.requires_trial_dates rescue false
end

def cracked_case?
  @record.case_type.name.match(/[Cc]racked/) rescue false
end

def has_fees_or_expenses_attributes?
  (@record.fixed_fees.present? || @record.misc_fees.present?) || (@record.basic_fees.present? || @record.expenses.present?)
end

def fixed_fee_case?
  @record.case_type.is_fixed_fee? rescue false
end

end
