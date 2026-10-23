# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkViewerHelper, type: :helper do
  let(:presenter) { double(id: 'work') }
  let(:resolver) { instance_double(Resolvers::WorkViewerResolver) }
  let(:download_routes) { Hyrax::Engine.routes.url_helpers }

  before do
    allow(Resolvers::WorkViewerResolver).to receive(:new).with(presenter: presenter).and_return(resolver)
  end

  it 'delegates viewer selection and reuses a resolver for the work' do
    allow(resolver).to receive(:images?).and_return(true)
    allow(resolver).to receive(:pdf_file_id).and_return('pdf')

    expect(helper.default_viewer_for_work(presenter)).to eq('images')
    expect(helper.has_images_for_work?(presenter)).to be true
    expect(helper.pdf_viewer_file_id_for_work(presenter)).to eq('pdf')
    expect(Resolvers::WorkViewerResolver).to have_received(:new).once
  end

  it 'defaults to the PDF viewer when no images are available' do
    allow(resolver).to receive(:images?).and_return(false)
    expect(helper.default_viewer_for_work(presenter)).to eq('pdf')
  end

  it 'keeps resolver instances separate for different works' do
    other_presenter = double(id: 'other-work')
    other_resolver = instance_double(Resolvers::WorkViewerResolver, images?: false)
    allow(Resolvers::WorkViewerResolver).to receive(:new).with(presenter: other_presenter).and_return(other_resolver)
    allow(resolver).to receive(:images?).and_return(true)

    expect(helper.has_images_for_work?(presenter)).to be true
    expect(helper.has_images_for_work?(other_presenter)).to be false
  end

  it 'generates locale-free download URLs for selected derivatives' do
    allow(resolver).to receive(:preferred_download_member).with('source').and_return(double(id: 'presentation'))
    expect(download_routes).to receive(:download_path).with(id: 'presentation', locale: nil).and_call_original

    expect(helper.preferred_download_url_for_member(presenter, 'source')).to eq('/downloads/presentation')
  end

  it 'does not generate a download URL when no derivative is available' do
    allow(resolver).to receive(:preferred_download_member).with('source').and_return(nil)
    expect(download_routes).not_to receive(:download_path)
    expect(helper.preferred_download_url_for_member(presenter, 'source')).to be_nil
  end

  it 'uses the default PDF to resolve the HOCR download URL' do
    allow(resolver).to receive(:pdf_file_id).and_return('pdf')
    allow(resolver).to receive(:hocr_file_id).with('pdf').and_return('hocr')
    expect(download_routes).to receive(:download_path).with(id: 'hocr', locale: nil).and_call_original

    expect(helper.hocr_download_url_for_work(presenter)).to eq('/downloads/hocr')
  end

  it 'respects an explicit PDF identifier and leaves missing HOCR absent' do
    expect(resolver).not_to receive(:pdf_file_id)
    allow(resolver).to receive(:hocr_file_id).with('explicit').and_return(nil)
    expect(download_routes).not_to receive(:download_path)

    expect(helper.hocr_download_url_for_work(presenter, pdf_file_id: 'explicit')).to be_nil
  end

  it 'generates the direct PDF download URL without a locale' do
    expect(download_routes).to receive(:download_path).with(id: 'pdf', locale: nil).and_call_original
    expect(helper.pdf_download_url_for_file('pdf')).to eq('/downloads/pdf')
  end

  it 'generates viewer-specific manifest URLs without retaining an existing query' do
    routes = double
    allow(helper).to receive(:main_app).and_return(routes)
    allow(routes).to receive(:polymorphic_url).with([:manifest, presenter], locale: nil)
                                            .and_return('https://example.org/manifest?locale=en')

    expect(helper.ramp_manifest_url_for_work(presenter)).to eq('https://example.org/manifest?viewer=ramp')
    expect(helper.clover_manifest_url_for_work(presenter)).to eq('https://example.org/manifest?viewer=clover')
  end
end
