# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LargeFileCharacterizationService do
  let(:file_set) { Hyrax::FileSet.new(id: 'file-set-1') }
  let(:file) { instance_double(Valkyrie::StorageAdapter::StreamFile, size: file_size) }
  let(:file_size) { 11.gigabytes }
  let(:metadata) do
    Hyrax::FileMetadata.new(
      id: 'file-metadata-1',
      file_set_id: file_set.id,
      file_identifier: 'fedora://original-file',
      original_filename: original_filename
    )
  end
  let(:original_filename) { 'large_video.mov' }
  let(:user) { instance_double(User) }

  before do
    allow(Hyrax).to receive(:persister).and_return(instance_double(Valkyrie::Persistence::Memory::Persister, save: metadata))
    allow(Hyrax).to receive(:publisher).and_return(instance_double(Hyrax::Publisher, publish: true))
    allow(Hyrax).to receive(:query_service).and_return(instance_double(Valkyrie::Persistence::Memory::QueryService, find_by: file_set))
    allow(Hyrax::Characterization::ValkyrieCharacterizationService).to receive(:run).and_return(true)
  end

  it 'infers characterization metadata from extension for recognized large files' do
    described_class.run(metadata: metadata, file: file, user: user)

    expect(metadata.mime_type).to eq('video/quicktime')
    expect(metadata.format_label).to contain_exactly('QuickTime video')
    expect(metadata.recorded_size).to contain_exactly(file_size.to_s)
    expect(Hyrax::Characterization::ValkyrieCharacterizationService).not_to have_received(:run)
    expect(Hyrax.publisher).to have_received(:publish).with('file.characterized', file_set: file_set, file_id: metadata.id.to_s, path_hint: metadata.file_identifier.to_s)
  end

  context 'when the file is below the large-file threshold' do
    let(:file_size) { 9.gigabytes }

    it 'delegates to Hyrax characterization' do
      described_class.run(metadata: metadata, file: file, user: user, ch12n_tool: :fits_servlet)

      expect(Hyrax::Characterization::ValkyrieCharacterizationService).to have_received(:run).with(metadata: metadata, file: file, user: user, ch12n_tool: :fits_servlet)
    end
  end

  context 'when the large file has an unrecognized extension' do
    let(:original_filename) { 'large_video.unknown' }

    it 'delegates to Hyrax characterization' do
      described_class.run(metadata: metadata, file: file, user: user)

      expect(Hyrax::Characterization::ValkyrieCharacterizationService).to have_received(:run).with(metadata: metadata, file: file, user: user)
    end
  end
end