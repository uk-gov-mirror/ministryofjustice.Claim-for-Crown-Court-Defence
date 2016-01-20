class ExternalUsers::ClaimsController < ExternalUsers::ApplicationController
  # This performs magic
  include DateParamProcessor
  include DocTypes

  helper_method :sort_column, :sort_direction

  respond_to :html

  before_action :set_user_and_provider
  before_action :set_context, only: [:index, :archived, :outstanding, :authorised]
  before_action :set_financial_summary, only: [:index, :outstanding, :authorised]
  before_action :initialize_json_document_importer, only: [:index]

  before_action :set_claim, only: [:show, :edit, :update, :clone_rejected, :destroy]
  before_action :set_doctypes, only: [:show]
  before_action :load_advocates_in_provider, only: [:new, :edit, :create, :update]
  before_action :generate_form_id, only: [:new, :edit]
  before_action :initialize_submodel_counts

  include ReadMessages
  include MessageControlsDisplay

  def index
    @claims = @context.claims.dashboard_displayable_states
    search if params[:search].present?
    sort_and_paginate(column: 'last_submitted_at', direction: 'asc', pagination: 10 )
  end

  def archived
    @claims = @context.claims.archived_pending_delete
    search(:archived_pending_delete) if params[:search].present?
    sort_and_paginate(column: 'last_submitted_at', direction: 'desc', pagination: 10 )
  end

  def outstanding
    @claims = @financial_summary.outstanding_claims
    sort_and_paginate(column: 'last_submitted_at', direction: 'asc', pagination: 10 )
    @total_value = @financial_summary.total_outstanding_claim_value
  end

  def authorised
    @claims = @financial_summary.authorised_claims
    sort_and_paginate(column: 'last_submitted_at', direction: 'desc', pagination: 10 )
    @total_value = @financial_summary.total_authorised_claim_value
  end

  def show
    @messages = @claim.messages.most_recent_last
    @message = @claim.messages.build
    @enable_assessment_input = false
  end

  def new
    @claim = Claim.new
    @advocates_in_provider = @provider.advocates if @external_user.admin?
    load_offences_and_case_types

    build_nested_resources
  end

  def edit
    build_nested_resources
    load_offences_and_case_types
    @disable_assessment_input = true

    redirect_to external_users_claims_url, notice: 'Can only edit "draft" claims' unless @claim.editable?
  end

  def confirmation; end

  def create
    @claim = Claim.new(params_with_advocate_and_creator)
    if submitting_to_laa?
      create_and_submit
    else
      create_draft
    end
  end

  def update
    update_source_for_api
    if @claim.update(claim_params)
      @claim.documents.each { |d| d.update_column(:external_user_id, @claim.external_user_id) }

      submit_if_required_and_redirect
    else
      present_errors
      render_edit_with_resources
    end
  end

  def clone_rejected
    begin
      draft = @claim.clone_rejected_to_new_draft
      send_ga('event', 'claim', 'draft', 'clone-rejected')
      redirect_to edit_external_users_claim_url(draft), notice: 'Draft created'
    rescue
      redirect_to external_users_claims_url, alert: 'Can only clone rejected claims'
    end
  end

  def destroy
    if @claim.draft?
      @claim.destroy
    else
      @claim.archive_pending_delete!
    end

    send_ga('event', 'claim', 'deleted')
    respond_with @claim, { location: external_users_claims_url, notice: 'Claim deleted' }
  end

  private

  def generate_form_id
    @form_id = SecureRandom.uuid
  end

  def load_offences_and_case_types
    @offence_descriptions = Offence.unique_name.order(description: :asc)
    if @claim.offence
      @offences = Offence.includes(:offence_class).where(description: @claim.offence.description)
    else
      @offences = Offence.includes(:offence_class)
    end
    @case_types = CaseType.all
  end

  def submit_if_required_and_redirect
    if submitting_to_laa?
      @claim.force_validation = true
      if @claim.valid?
        send_ga('event', 'claim', 'submit', 'started')
        redirect_to new_external_users_claim_certification_path(@claim)
      else
        present_errors
        render_edit_with_resources
      end
    else
      send_ga('event', 'claim', 'draft', 'updated')
      redirect_to external_users_claims_path, notice: 'Draft claim saved'
    end
  end

  def set_user_and_provider
    @external_user = current_user.persona
    @provider = @external_user.provider
  end

  def set_context
    if @external_user.admin? && @provider
      @context = @provider
    else
      @context = current_user
    end
  end

  def search(states=nil)
    @claims = @claims.search(params[:search], states, *search_options)
  end

  def search_options
    options = [:defendant_name]
    options << :advocate_name if @external_user.admin?
    options
  end

  def set_sort_defaults(defaults={})
    @sort_defaults = {  column:     defaults.has_key?(:column)      ? defaults[:column]     : 'last_submitted_at',
                        direction:  defaults.has_key?(:direction)   ? defaults[:direction]  : 'asc',
                        pagination: defaults.has_key?(:pagination)  ? defaults[:pagination] : 10
                      }
  end

  def sort_column
    @claims.sortable_by?(params[:sort]) ? params[:sort] : @sort_defaults[:column]
  end

  def sort_direction
    %w(asc desc).include?(params[:direction]) ? params[:direction] : @sort_defaults[:direction]
  end

  def sort_and_paginate(options={})
    set_sort_defaults(options)
    # GOTCHA: must paginate in same call that sorts/orders
    @claims = @claims.sort(sort_column, sort_direction).page(params[:page]).per(@sort_defaults[:pagination])
  end

  def load_advocates_in_provider
    @advocates_in_provider = @provider.advocates if @external_user.admin?
  end

  def set_claim
    @claim = Claim.find(params[:id])
  end

  def set_financial_summary
    @financial_summary = Claims::FinancialSummary.new(@context)
  end

  def claim_params
    params.require(:claim).permit(
     :form_id,
     :state_for_form,
     :source,
     :external_user_id,
     :court_id,
     :case_number,
     :case_type_id,
     :trial_fixed_notice_at_dd,
     :trial_fixed_notice_at_mm,
     :trial_fixed_notice_at_yyyy,
     :trial_fixed_at_dd,
     :trial_fixed_at_mm,
     :trial_fixed_at_yyyy,
     :trial_cracked_at_dd,
     :trial_cracked_at_mm,
     :trial_cracked_at_yyyy,
     :trial_cracked_at_third,
     :offence_id,
     :first_day_of_trial_dd,
     :first_day_of_trial_mm,
     :first_day_of_trial_yyyy,
     :estimated_trial_length,
     :actual_trial_length,
     :trial_concluded_at_dd,
     :trial_concluded_at_mm,
     :trial_concluded_at_yyyy,
     :advocate_category,
     :additional_information,
     :indictment_number,
     evidence_checklist_ids: [],
     defendants_attributes: [
       :id,
       :claim_id,
       :first_name,
       :last_name,
       :date_of_birth_dd,
       :date_of_birth_mm,
       :date_of_birth_yyyy,
       :order_for_judicial_apportionment,
       :_destroy,
       representation_orders_attributes: [
         :id,
         :document,
         :maat_reference,
         :representation_order_date_dd,
         :representation_order_date_mm,
         :representation_order_date_yyyy,
         :_destroy
        ]
     ],
     basic_fees_attributes: [
       :id,
       :claim_id,
       :fee_type_id,
       :fee_id,
       :quantity,
       :rate,
       :amount,
       :_destroy,
       dates_attended_attributes: [
          :id,
          :fee_id,
          :date_dd,
          :date_mm,
          :date_yyyy,
          :date_to_dd,
          :date_to_mm,
          :date_to_yyyy,
          :_destroy
        ]
     ],
      fixed_fees_attributes: [
       :id,
       :claim_id,
       :fee_type_id,
       :fee_id,
       :quantity,
       :rate,
       :_destroy,
       dates_attended_attributes: [
          :id,
          :fee_id,
          :date_dd,
          :date_mm,
          :date_yyyy,
          :date_to_dd,
          :date_to_mm,
          :date_to_yyyy,
          :_destroy
        ]
      ],
      misc_fees_attributes: [
       :id,
       :claim_id,
       :fee_type_id,
       :fee_id,
       :quantity,
       :rate,
       :_destroy,
       dates_attended_attributes: [
          :id,
          :fee_id,
          :date_dd,
          :date_mm,
          :date_yyyy,
          :date_to_dd,
          :date_to_mm,
          :date_to_yyyy,
          :_destroy
        ]
      ],
     expenses_attributes: [
       :id,
       :claim_id,
       :expense_type_id,
       :location,
       :quantity,
       :rate,
       :_destroy,
       dates_attended_attributes: [
          :id,
          :expense_id,
          :date_dd,
          :date_mm,
          :date_yyyy,
          :date_to_dd,
          :date_to_mm,
          :date_to_yyyy,
          :_destroy
        ]
     ]
    )
  end

  def build_nested_resources
    [:defendants, :fixed_fees, :misc_fees, :expenses, :documents].each do |association|
      build_nested_resource(@claim, association)
    end

    @claim.defendants.each { |d| build_nested_resource(d, :representation_orders) }
  end

  def build_nested_resource(object, association)
    object.send(association).build if object.send(association).none?
  end

  def update_source_for_api
    @claim.update(source: 'api_web_edited') if @claim.from_api?
  end

  def saving_to_draft?
    params[:commit] == 'Save to drafts'
  end

  def submitting_to_laa?
    params[:commit] == 'Submit to LAA'
  end

  def render_edit_with_resources
    build_nested_resources
    load_offences_and_case_types
    render action: :edit
  end

  def render_new_with_resources
    present_errors
    build_nested_resources
    load_offences_and_case_types
    render action: :new
  end

  def params_with_advocate_and_creator
    form_params = claim_params
    form_params[:external_user_id] = @external_user.id unless @external_user.admin?
    form_params[:creator_id] = @external_user.id
    form_params
  end

  def create_draft
    if @claim.save
      @claim.documents.each { |d| d.update_column(:external_user_id, @claim.external_user_id) }
      send_ga('event', 'claim', 'draft', 'created')
      redirect_to external_users_claims_path, notice: 'Draft claim saved'
    else
      render_new_with_resources
    end
  end

  def initialize_submodel_counts
    @defendant_count            = 0
    @representation_order_count = 0
    @basic_fee_count            = 0
    @basic_fee_date_attended_count = 0
    @misc_fee_count             = 0
    @misc_fee_date_attended_count = 0
    @fixed_fee_count            = 0
    @fixed_fee_date_attended_count = 0
    @expense_count              = 0
    @expense_date_attended_count= 0
  end

  def create_and_submit
    Claim.transaction do
      @claim.save
      @claim.force_validation = true

      if @claim.valid?
        @claim.documents.each { |d| d.update_column(:external_user_id, @claim.external_user_id) }
        send_ga('event', 'claim', 'submit', 'started')
        redirect_to new_external_users_claim_certification_path(@claim) and return
      else
        raise ActiveRecord::Rollback
      end
    end
    render_new_with_resources
  end

  def present_errors
    @error_presenter = ErrorPresenter.new(@claim)
  end

  def initialize_json_document_importer
    @json_document_importer = JsonDocumentImporter.new
  end


end
