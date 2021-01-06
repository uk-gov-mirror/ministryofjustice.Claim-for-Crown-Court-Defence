module ActiveStorageMigration
  def convert_to_active_storage asset
    paperclip = send asset
    return unless paperclip.exists?

    blob = ActiveStorage::Blob.create!(
      filename: paperclip.original_filename,
      byte_size: paperclip.size,
      checksum: 'test'
    )

    source = paperclip.path
    dest_dir = File.join(
      "storage",
      blob.key.first(2),
      blob.key.first(4).last(2))
    dest = File.join(dest_dir, blob.key)

    FileUtils.mkdir_p(dest_dir)
    FileUtils.cp(source, dest)

    ActiveStorage::Attachment.create!(
      name: asset,
      record: self,
      blob: blob
    )
  end
end