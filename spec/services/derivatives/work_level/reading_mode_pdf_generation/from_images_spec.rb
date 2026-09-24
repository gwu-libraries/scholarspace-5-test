# frozen_string_literal: true

require 'rails_helper'
require 'fileutils'

RSpec.describe Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages do
  subject(:service) { described_class.new(work) }

  let(:work) { instance_double('Work', id: 'work-2', depositor: 'depositor@example.edu', member_file_sets: member_file_sets, member_ids: member_ids) }
  let(:member_file_sets) { [] }
  let(:member_ids) { [] }

  describe '#generate_to_cache' do
    let(:source_file_set_1) do
      instance_double('FileSet', id: 'fs-1', original_file: source_file_1, title: [])
    end
    let(:source_file_set_2) do
      instance_double('FileSet', id: 'fs-2', original_file: source_file_2, title: [])
    end
    let(:source_file_1) do
      instance_double('OriginalFile', mime_type: 'image/jpeg', original_filename: 'page-1.jpg', file_identifier: 'fid-1')
    end
    let(:source_file_2) do
      instance_double('OriginalFile', mime_type: 'image/jpeg', original_filename: 'page-2.jpg', file_identifier: 'fid-2')
    end

    before do
      service.instance_variable_set(:@working_dir, '/tmp/workdir')
      allow(Dir).to receive(:mkdir)
      allow(service).to receive(:depositor).and_return(instance_double('User'))
      allow(service).to receive(:copy_file_to_disk) do |_identifier, destination|
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.touch(destination)
        destination
      end
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/workdir/pdfs/page_0001.pdf').and_return(false)
      allow(File).to receive(:exist?).with('/tmp/workdir/pdfs/page_0002.pdf').and_return(false)
      allow(File).to receive(:exist?).with('/tmp/workdir/pdfs/reading_mode_pdf.pdf').and_return(true)
    end

    it 'converts each image to a single-page PDF then concatenates with gs' do
      success_status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(['', '', success_status])

      service.send(:join_images_to_pdf, ['/tmp/0001.jpg', '/tmp/0002.jpg'])

      expect(Open3).to have_received(:capture3).with(
        'magick', 'convert', '-quality', '88', '-density', '150x150',
        '/tmp/0001.jpg', '/tmp/workdir/pdfs/page_0001.pdf'
      )
      expect(Open3).to have_received(:capture3).with(
        'magick', 'convert', '-quality', '88', '-density', '150x150',
        '/tmp/0002.jpg', '/tmp/workdir/pdfs/page_0002.pdf'
      )
      expect(Open3).to have_received(:capture3).with(
        'gs', '-dBATCH', '-dNOPAUSE', '-sDEVICE=pdfwrite', '-dCompatibilityLevel=1.4',
        '-sOutputFile=/tmp/workdir/pdfs/reading_mode_pdf.pdf',
        '/tmp/workdir/pdfs/page_0001.pdf',
        '/tmp/workdir/pdfs/page_0002.pdf'
      )
      expect(service.instance_variable_get(:@joined_pdf_path)).to eq('/tmp/workdir/pdfs/reading_mode_pdf.pdf')
    end

    it 'attaches the reading mode PDF to the work' do
      depositor = instance_double('User')
      file_set = instance_double('FileSet', id: 'joined-pdf-1')
      allow(file_set).to receive(:service_file=)
      allow(service).to receive(:depositor).and_return(depositor)
      allow(service).to receive(:with_work_lock).and_yield
      allow(service).to receive(:reload_work).and_return(work)
      allow(service).to receive(:create_file_set_for_upload).and_return(file_set)
      allow(service).to receive(:save_and_index).with(file_set).and_return(file_set)
      allow(service).to receive(:cache_derivative)
      allow(work).to receive(:member_ids=) { |ids| member_ids.replace(ids) }
      allow(Hyrax).to receive(:persister).and_return(instance_double('Persister', save: work))
      allow(File).to receive(:open).with('/tmp/workdir/pdfs/reading_mode_pdf.pdf', 'rb').and_yield(StringIO.new('pdf'))

      result = service.send(:attach_pdf_to_work, '/tmp/workdir/pdfs/reading_mode_pdf.pdf', source_file_set: source_file_set_1)

      expect(service).to have_received(:create_file_set_for_upload).with(
        file_path: '/tmp/workdir/pdfs/reading_mode_pdf.pdf',
        user: depositor,
        io: an_instance_of(StringIO),
        source_file_set: source_file_set_1,
        skip_derivatives: true,
        derivative_type: Constants::DerivativeTypeConstants::DERIVATIVE_TYPE_PRESENTATION_VERSION
      )
      expect(file_set).to have_received(:service_file=).with(true)
      expect(member_ids).to eq(['joined-pdf-1'])
      expect(service).to have_received(:cache_derivative).with(
        file_path: '/tmp/workdir/pdfs/reading_mode_pdf.pdf',
        file_set: file_set,
        derivative_type: Constants::DerivativeTypeConstants::DERIVATIVE_TYPE_PRESENTATION_VERSION
      )
      expect(result).to eq(file_set)
    end
  end
end