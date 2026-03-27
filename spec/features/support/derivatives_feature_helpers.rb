# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module DerivativesFeatureHelpers
  def attach_fixture_to_work(work:, user:, fixture_path:)
    filename = File.basename(fixture_path)
    temp_dir = Dir.mktmpdir('fixture_upload_')
    temp_fixture_path = File.join(temp_dir, filename)
    FileUtils.cp(fixture_path, temp_fixture_path)
    file_io = File.open(temp_fixture_path, 'rb')

    file_set = Hyrax.persister.save(
      resource: Hyrax.config.valkyrie_file_set_class.new(
        depositor: user.user_key,
        creator: [user.user_key],
        title: [filename],
        label: filename,
        date_uploaded: Time.current,
        date_modified: Time.current
      )
    )

    Hyrax::ValkyrieUpload.file(filename: filename, file_set: file_set, io: file_io, user: user)

    work.member_ids += [file_set.id]
    work.representative_id = file_set.id if work.respond_to?(:representative_id) && work.representative_id.blank?
    work.thumbnail_id = file_set.id if work.respond_to?(:thumbnail_id) && work.thumbnail_id.blank?
    Hyrax.persister.save(resource: work)
  ensure
    file_io&.close
    FileUtils.remove_entry(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  end

  def member_filenames_for(resource)
    refreshed = Hyrax.query_service.find_by(id: resource.id)

    refreshed.member_ids.filter_map do |member_id|
      file_set = Hyrax.query_service.find_by(id: member_id)
      file_set.original_file&.original_filename.to_s.presence
    end
  end
end