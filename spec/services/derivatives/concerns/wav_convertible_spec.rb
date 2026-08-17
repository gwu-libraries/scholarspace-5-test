# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::Concerns::TranscriptExtraction::WavConvertible do
  let(:test_class) do
    Class.new do
      include Derivatives::Concerns::TranscriptExtraction::WavConvertible
    end
  end

  subject(:service) { test_class.new }

  let(:fake_success) { instance_double(Process::Status, success?: true) }
  let(:fake_failure) { instance_double(Process::Status, success?: false) }

  describe '#transcription_source_path' do
    it 'returns the original path unchanged when the file is already a WAV' do
      result = service.send(:transcription_source_path, '/tmp/audio.wav')
      expect(result).to eq('/tmp/audio.wav')
    end

    it 'converts a non-WAV file to WAV and returns the output path' do
      wav_path = '/tmp/audio_whisper.wav'
      allow(Open3).to receive(:capture3).and_return(['', '', fake_success])
      allow(File).to receive(:exist?) { |path| path == wav_path }

      result = service.send(:transcription_source_path, '/tmp/audio.mp4')
      expect(result).to eq(wav_path)
    end
  end

  describe '#convert_to_wav' do
    let(:source_path) { '/tmp/my_video.mp4' }
    let(:wav_path)    { '/tmp/my_video_whisper.wav' }

    it 'calls ffmpeg with the correct arguments and returns the output WAV path' do
      allow(Open3).to receive(:capture3).with(
        'ffmpeg', '-y', '-i', source_path,
        '-vn', '-acodec', 'pcm_s16le', '-ar', '16000', '-ac', '1', wav_path
      ).and_return(['', '', fake_success])
      allow(File).to receive(:exist?) { |path| path == wav_path }

      result = service.send(:convert_to_wav, source_path)
      expect(result).to eq(wav_path)
    end

    it 'raises an error when ffmpeg exits with a non-zero status' do
      allow(Open3).to receive(:capture3).and_return(['', 'ffmpeg: No such file', fake_failure])

      expect {
        service.send(:convert_to_wav, source_path)
      }.to raise_error(RuntimeError, /Failed to convert/)
    end

    it 'raises an error when ffmpeg succeeds but the output file is not created' do
      allow(Open3).to receive(:capture3).and_return(['', '', fake_success])
      allow(File).to receive(:exist?) { |path| path != wav_path }

      expect {
        service.send(:convert_to_wav, source_path)
      }.to raise_error(RuntimeError, /Failed to convert/)
    end
  end
end
