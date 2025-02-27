require 'tasks/rake_helpers/storage.rb'

namespace :storage do
  desc 'Migrate assets from Paperclip to Active Storage'
  task :migrate, [:model] => :environment do |_task, args|
    Storage.migrate args[:model]
  end

  desc 'Rollback asset migration'
  task :rollback, [:model] => :environment do |_task, args|
    production_protected
    Storage.rollback args[:model]
  end

  desc 'Create/replace dummy paperclip asset files, based on attachment metadata'
  task :create_dummy_paperclip_files, [:model] => :environment do |_task, args|
    production_protected
    continue?("Warning: this will overwrite existing files for #{args[:model]} with random bytes! Are you sure?")

    Storage.create_dummy_paperclip_files_for(args[:model])
  end

  desc 'Clear dummy paperclip asset files, but leave attachment meta data in place'
  task :clear_dummy_paperclip_files, [:model] => :environment do |_task, args|
    production_protected
    continue?("Warning: this will delete existing files for #{args[:model]}! Are you sure?")

    Storage.clear_dummy_paperclip_files_for(args[:model])
  end

  desc 'Add file checksums to paperclip columns'
  task :add_paperclip_checksums, [:model, :limit, :prompt] => :environment do |_task, args|
    continue?("Set paperclip checksums for #{args[:limit] || 'all'} records of #{args[:model]}?") unless args[:prompt].eql?('no_prompt')

    module TempStats
      class StatsReport < ApplicationRecord
        include S3Headers
        include CheckSummable

        self.table_name = 'stats_reports'
        has_attached_file :document, s3_headers.merge(REPORTS_STORAGE_OPTIONS)

        def populate_checksum
          add_checksum(:document) unless document_file_name.nil?
        end
      end
    end

    class TempMessage < ApplicationRecord
      include S3Headers
      include CheckSummable

      self.table_name = 'messages'
      has_attached_file :attachment, s3_headers.merge(PAPERCLIP_STORAGE_OPTIONS)

      def populate_checksum
        add_checksum(:attachment) unless attachment_file_name.nil?
      end
    end

    class TempDocument < ApplicationRecord
      include S3Headers
      include CheckSummable

      self.table_name = 'documents'
      has_attached_file :converted_preview_document, s3_headers.merge(PAPERCLIP_STORAGE_OPTIONS)
      has_attached_file :document, s3_headers.merge(PAPERCLIP_STORAGE_OPTIONS)

      def populate_checksum
        add_checksum(:document) unless document_file_name.nil?
        add_checksum(:converted_preview_document) unless converted_preview_document.nil?
      end
    end

    case args[:model]
    when 'stats_reports'
      relation = TempStats::StatsReport.where.not(document_file_name: nil).where(as_document_checksum: nil)
    when 'messages'
      relation = TempMessage.where.not(attachment_file_name: nil).where(as_attachment_checksum: nil)
    when 'documents'
      relation = TempDocument.where(as_document_checksum: nil)
    else
      puts "Cannot calculate checksums for: #{args[:model]}"
      exit
    end
    relation = relation.limit(args[:limit]) if args[:limit]

    puts "Setting paperclip checksums for #{args[:limit] || 'all'} records of #{relation.table_name.green}"
    Storage.set_paperclip_checksums(relation: relation)

    Rake::Task['storage:status'].invoke
  end

  desc 'Clear temporary paperclip checksums for specified model'
  task :clear_paperclip_checksums, [:model] => :environment do |_task, args|
    continue?("Clear paperclip checksums for all records of #{args[:model]}?")
    Storage.clear_paperclip_checksums args[:model]
  end

  desc 'Show status of storage migration'
  task status: :environment do

    Storage.status('stats_reports')
    puts
    Storage.status('messages')
    puts
    Storage.status('documents')
  end
end
