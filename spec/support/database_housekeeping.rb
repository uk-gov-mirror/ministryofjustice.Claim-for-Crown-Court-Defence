module DatabaseHousekeeping
	def clean_database
		models = [
      CaseType,
      Expense,
      ClaimStateTransition,
      Claim,
      DateAttended,
      Defendant,
      Determination,
      Document,
      ExpenseType,
      FeeType,
      Fee,
      Location,
      OffenceClass,
      Offence,
      FeeCategory,
      RepresentationOrder,
      SuperAdmin,
      UserMessageStatus,
      User,
      CaseWorkerClaim,
      Message,
      Court,
      CaseWorker,
      CertificationType,
      Certification,
      ClaimIntention,
      ExternalUser,
      Provider,
    ]

    models.each do |model|
      model.delete_all
    end
  end

  def report_record_counts
    tables = ActiveRecord::Base.connection.tables
    tables.each do |t|
      next if t == 'schema_migrations'
      next if t == 'versions'
      puts "#{t.classify} #{t.classify.constantize.count}"
    end
  end
end
