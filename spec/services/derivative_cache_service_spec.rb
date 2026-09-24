# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeCacheService do
  let(:service) { described_class.new(cache_root: Dir.mktmpdir) }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:bucket) { 'cache-bucket' }
  let(:file_identifier) { 'derivatives:work:1:source:2:image.jpg' }
  let(:filename) { 'image.jpg' }

  after do
    FileUtils.rm_rf(service.instance_variable_get(:@cache_root))
  end

  describe 'filesystem storage' do
    it 'stores and fetches a derivative when S3 is not configured' do
      source = Tempfile.new(['derivative', '.jpg'])
      source.write('derivative bytes')
      source.close

      service.store_from_path(
        file_identifier: file_identifier,
        original_filename: filename,
        source_path: source.path
      )

      stream = service.fetch_stream(file_identifier: file_identifier, original_filename: filename)
      expect(stream.read).to eq('derivative bytes')
      expect(service.cached?(file_identifier: file_identifier, original_filename: filename)).to be true

      expect(
        service.store_derivative_from_path(
          file_identifier: file_identifier,
          original_filename: filename,
          source_path: source.path
        )
      ).to eq(service.store_from_path(
                file_identifier: file_identifier,
                original_filename: filename,
                source_path: source.path
              ))
    ensure
      stream&.close
      source&.unlink
    end
  end

  describe 'S3 storage' do
    before do
      stub_const('Aws::S3::Client', Class.new)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('S3_DERIVATIVE_CACHE_BUCKET').and_return(bucket)
    end

    it 'uploads a source path to the configured bucket and returns its object key' do
      source = Tempfile.new(['derivative', '.jpg'])
      source.write('derivative bytes')
      source.close
      allow(s3_client).to receive(:put_object)

      key = service.store_from_path(
        file_identifier: file_identifier,
        original_filename: filename,
        source_path: source.path
      )

      expect(key).to match(%r{\A[0-9a-f]{2}/[0-9a-f]{64}\.jpg\z})
      expect(s3_client).to have_received(:put_object).with(bucket: bucket, key: key, body: instance_of(File))
    ensure
      source&.unlink
    end

    it 'returns a stream for an existing object and nil for a missing object' do
      response = instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new('derivative bytes'))
      allow(s3_client).to receive(:get_object).and_return(response)

      stream = service.fetch_stream(file_identifier: file_identifier, original_filename: filename)

      expect(stream.read).to eq('derivative bytes')
      expect(s3_client).to have_received(:get_object).with(bucket: bucket, key: kind_of(String))
    ensure
      stream&.close
    end

    it 'checks existence with HEAD' do
      allow(s3_client).to receive(:head_object)

      expect(service.cached?(file_identifier: file_identifier, original_filename: filename)).to be true
      expect(s3_client).to have_received(:head_object).with(bucket: bucket, key: kind_of(String))
    end
  end
end
