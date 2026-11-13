# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::TranscriptExtraction::VttGeneratable do
  let(:test_class) do
    Class.new do
      include Derivatives::TranscriptExtraction::VttGeneratable
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

    context 'when Whisper returns UTF-8 bytes tagged as ASCII-8BIT' do
      let(:expected_content) { "WEBVTT\n\n1\n00:00:00.000 --> 00:00:05.000\n\u201cHello\u201d \u2014 caf\u00e9\n" }
      let(:vtt_content) { expected_content.b.freeze }

      it 'preserves non-ASCII text and writes valid UTF-8 without mutating the output' do
        vtt_path = service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')
        written = File.read(vtt_path, encoding: Encoding::UTF_8)

        expect(written).to eq(expected_content)
        expect(written).to be_valid_encoding
        expect(File.binread(vtt_path)).to eq(vtt_content)
        expect(vtt_content.encoding).to eq(Encoding::ASCII_8BIT)
      end
    end

    context 'when Whisper returns text in another declared encoding' do
      let(:vtt_content) { "WEBVTT\n\ncaf\u00e9\n".encode(Encoding::ISO_8859_1) }

      it 'transcodes the text to UTF-8' do
        vtt_path = service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')

        expect(File.read(vtt_path, encoding: Encoding::UTF_8)).to eq("WEBVTT\n\ncaf\u00e9\n")
      end
    end

    context 'when Whisper returns invalid UTF-8 bytes' do
      let(:vtt_content) { "WEBVTT\n\n\xE2".b }

      it 'raises rather than writing a corrupt transcript' do
        expect do
          service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')
        end.to raise_error(Encoding::InvalidByteSequenceError, /UTF-8/)

        expect(File).not_to exist("#{output_dir}/clip_VTT.vtt")
      end
    end

    it 'derives the title from the file basename when no title is given' do
      vtt_path = service.send(:generate_vtt, '/tmp/my_video.mp4', output_dir: output_dir)

      expect(File.basename(vtt_path)).to eq('my_video_VTT.vtt')
    end

    it 'calls Whisper::Context.new with the base model' do
      service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')

      expect(Whisper::Context).to have_received(:new).with('base')
    end

    it 'uses the configured transcription model' do
      allow(Configuration::DerivativeSettings).to receive(:fetch).with(:transcription, :model).and_return('tiny')
      allow(Whisper::Context).to receive(:new).with('tiny').and_return(whisper_context)

      service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')

      expect(Whisper::Context).to have_received(:new).with('tiny')
    end

    it 'transcribes the given file path' do
      service.send(:generate_vtt, '/tmp/audio.wav', output_dir: output_dir, title: 'clip')

      expect(whisper_context).to have_received(:transcribe).with('/tmp/audio.wav', whisper_params)
    end
  end
end
