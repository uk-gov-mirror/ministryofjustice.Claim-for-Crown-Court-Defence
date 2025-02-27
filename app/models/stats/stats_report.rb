# == Schema Information
#
# Table name: stats_reports
#
#  id           :integer          not null, primary key
#  report_name  :string
#  report       :string
#  status       :string
#  started_at   :datetime
#  completed_at :datetime
#

module Stats
  class StatsReport < ApplicationRecord
    include S3Headers
    include CheckSummable

    TYPES = %w[management_information provisional_assessment rejections_refusals].freeze

    validates :status, inclusion: { in: %w[started completed error] }

    default_scope { order('started_at DESC') }

    scope :completed, -> { where(status: 'completed') }
    scope :errored, -> { where(status: 'error') }
    scope :not_errored, -> { where.not(status: 'error') }

    scope :management_information, -> { not_errored.where(report_name: 'management_information') }
    scope :provisional_assessment, -> { not_errored.where(report_name: 'provisional_assessment') }

    before_destroy -> { document.purge }

    has_one_attached :document

    def self.clean_up(report_name)
      destroy_reports_older_than(report_name, 1.month.ago)
      destroy_unfinished_reports_older_than(report_name, 2.hours.ago)
    end

    def self.most_recent_by_type(report_type)
      where(report_name: report_type).completed.first
    end

    def self.most_recent_management_information
      management_information.completed.first
    end

    def self.generation_in_progress?(report_name)
      where('report_name = ? and status = ?', report_name, 'started').any?
    end

    def self.record_start(report_name)
      create!(report_name: report_name, status: 'started', started_at: Time.now)
    end

    # High ABC Size due to setting Paperclip fields for possible revert.
    # This 'rubocop:disable' can be removed when the Paperclip fields are removed.
    # rubocop:disable Metrics/AbcSize
    def write_report(report_result)
      filename = "#{report_name}_#{started_at.to_s(:number)}.#{report_result.format}"
      log(:info, :write_report, "Writing report #{report_name} to #{filename}")
      document.attach(io: report_result.io, filename: filename, content_type: report_result.content_type)
      update(
        status: 'completed',
        completed_at: Time.zone.now,
        document_file_name: filename,
        document_file_size: document.byte_size,
        document_content_type: report_result.content_type,
        document_updated_at: document.created_at,
        as_document_checksum: document.checksum
      )
    rescue StandardError => e
      log(:error, :write_report, "error writing report #{report_name}...", e)
      raise
    end
    # rubocop:enable Metrics/AbcSize

    def write_error(report_contents)
      update(report: report_contents, status: 'error', completed_at: nil)
    end

    def document_url(timeout = 10_000)
      return unless document?
      document.options[:storage] == :filesystem ? document.path : document.expiring_url(timeout)
    end

    def download_filename
      "#{report_name}_#{started_at.to_s(:number)}.csv"
    end

    def self.destroy_reports_older_than(report_name, timestamp)
      where(report_name: report_name, started_at: Time.at(0)..timestamp).destroy_all
    end

    def self.destroy_unfinished_reports_older_than(report_name, timestamp)
      where(report_name: report_name, status: 'started', started_at: Time.at(0)..timestamp).destroy_all
    end

    def populate_checksum
      add_checksum(:document)
    end

    private

    def log(level, action, message, error = nil)
      LogStuff.send(
        level.to_sym,
        class: self.class.name,
        action: action,
        error: error ? "#{error.class} - #{error.message}" : 'false'
      ) do
        message
      end
    end
  end
end
