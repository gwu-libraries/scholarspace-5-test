# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScholarspaceDerivativesServices::Concerns::VttGeneratable do
  let(:test_class) do
    Class.new do
      include ScholarspaceDerivativesServices::Concerns::VttGeneratable
    end
  end

  subject(:service) { test_class.new }

  let(:output_dir) { Dir.mktmpdir('vtt_spec_') }

  after { FileUtils.remove_entry(output_dir) if Dir.exist?(output_dir) }

  let(:whisper_context) { instance_double(Whisper::Context) }
  let(:whisper_params)  { instance_double(Whisper::Params) }
  let(:vtt_content)     { "WEBVTT\n\n1\n00:00:00.000 --> 00:00:05.000\nHello world\n" }
  let(:transcription)   { instance_double('Whisper::Transcription', to_webvtt: vtt_content) }

  before do
    allow(Whisper::Context).to receive(:new).with('base').and_return(whisper_context)
    allow(Whisper::Params).to receive(:new).and_return(whisper_params)
    allow(whisper_context).to receive(:transcribe).with(anything, whisper_params).and_return(transcription)
    allow(FileUtils).to receive(:mkdir_p)
    allow(ENV).to receive(:[]=)
  end

  describe '#generate_vtt' do
    it 'writes VTT content to the output path and returns the path' do
      vtt_path = service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'my_audio')

      expect(vtt_path).to eq("#{output_dir}/my_audio_VTT.vtt")
      expect(File.read(vtt_path)).to include('WEBVTT')
    end

    it 'derives the title from the file basename when no title is given' do
      vtt_path = service.send(:generate_vtt, '/tmp/my_video.mp4', output_dir: output_dir)

      expect(File.basename(vtt_path)).to eq('my_video_VTT.vtt')
    end

    it 'calls Whisper::Context.new with the base model' do
      service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')

      expect(Whisper::Context).to have_received(:new).with('base')
    end

    it 'transcribes the given file path' do
      service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')

      expect(whisper_context).to have_received(:transcribe).with('/tmp/audio.wav', whisper_params)
    end
  end
end
