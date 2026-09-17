# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestLifecycleInstrumentation do
  let(:file) { instance_double(Hyrax::UploadedFile, id: 139, file: 'example.mov', file_set_uri: 'file-set-1') }
  let(:logger) { instance_double(ActiveSupport::Logger, info: nil, error: nil) }
  let(:base_class) do
    Class.new do
      attr_accessor :failure

      def perform(_file, **_options)
        raise failure if failure

        :completed
      end
    end
  end
  let(:job_class) do
    Class.new(base_class) do
      prepend IngestLifecycleInstrumentation
    end
  end

  before do
    allow(Rails).to receive(:logger).and_return(logger)
  end

  it 'logs ingest start and completion' do
    expect(job_class.new.perform(file)).to eq(:completed)

    expect(logger).to have_received(:info).twice
    expect(logger).to have_received(:info).with(a_string_including('"event":"started"', '"uploaded_file_id":139', '"file_set_id":"file-set-1"'))
    expect(logger).to have_received(:info).with(a_string_including('"event":"completed"', '"elapsed_seconds"'))
  end

  it 'logs failures and re-raises them' do
    job = job_class.new
    job.failure = Ldp::Conflict.new('Fedora conflict')

    expect { job.perform(file) }.to raise_error(Ldp::Conflict, 'Fedora conflict')

    expect(logger).to have_received(:error).with(a_string_including('"event":"failed"', '"error_class":"Ldp::Conflict"'))
  end
end
