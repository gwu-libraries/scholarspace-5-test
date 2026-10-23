# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::DownloadsController do
  before do
    require_dependency Rails.root.join('app/controllers/hyrax/downloads_controller_decorator').to_s
  end

  describe '#file_set_parent' do
    subject(:controller) { described_class.new }

    let(:file_set_id) { 'file-set-id' }
    let(:parent) { instance_double('parent') }
    let(:file_set) { instance_double('file_set', parent: parent) }

    before do
      allow(Hyrax.config).to receive(:disable_wings).and_return(false)
      allow(Hyrax.query_service).to receive(:find_by).with(id: file_set_id).and_return(file_set)
    end

    it 'does not reference Wings constants when Wings is not loaded' do
      expect(controller.send(:file_set_parent, file_set_id)).to eq(parent)
    end
  end
end