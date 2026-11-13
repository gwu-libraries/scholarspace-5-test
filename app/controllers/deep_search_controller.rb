# frozen_string_literal: true

require 'nokogiri'
require 'open3'
require 'tempfile'

class DeepSearchController < ApplicationController
  def deep_search
    query = params[:q].to_s.strip
    return render json: empty_search_payload(query) if query.blank?

    escaped_work_id = RSolr.solr_escape(params[:id].to_s)
    escaped_query = RSolr.solr_escape(query)
    scope = params[:scope].to_s
    escaped_file_id = RSolr.solr_escape(params[:file_id].to_s)
    file_scope = if scope == 'current_file' && escaped_file_id.present?
                   " AND (id:\"#{escaped_file_id}\" OR related_url_tesim:\"source_file_set_id:#{escaped_file_id}\")"
                 else
                   ''
                 end
    type_scope = case scope
                 when 'all_images'
                   ' AND (title_tesim:*.hocr OR file_format_tesim:*image*)'
                 when 'all_av'
                   ' AND (title_tesim:*.vtt OR file_format_tesim:*audio* OR file_format_tesim:*video*)'
                 when 'all_pdfs'
                   ' AND (title_tesim:*.pdf OR file_format_tesim:*pdf*)'
                 else
                   ''
                 end
    response = Hyrax.index_adapter.connection.get(
      'select',
      params: {
        q: "parent_work_id_ssim:\"#{escaped_work_id}\"#{file_scope}#{type_scope} AND all_text_tsimv:\"#{escaped_query}\"",
        fl: 'id,title_tesim,file_format_tesim,all_text_tsimv,hocr_markup,service_file_bsi,related_url_tesim',
        rows: 50,
        facet: false,
        hl: true,
        'hl.fl': 'all_text_tsimv',
        'hl.snippets': 3,
        'hl.fragsize': 180
      }
    )

    render json: search_payload(query, response)
  rescue StandardError => e
    Rails.logger.warn("Deep search failed: #{e.class}: #{e.message}")
    render json: empty_search_payload(query)
  end

  private

  def empty_search_payload(query)
    { query: query, imageResults: [], pdfResults: [], avResults: [] }
  end

  def search_payload(query, response)
    docs = response.dig('response', 'docs') || []
    highlights = response['highlighting'] || {}
    results = docs.flat_map do |document|
      file_id = document['id'].to_s
      label = Array(document['title_tesim']).first.to_s.presence || file_id
      format = Array(document['file_format_tesim']).first.to_s.downcase
      filename = Array(document['title_tesim']).first.to_s.downcase
      text = Array(highlights.dig(file_id, 'all_text_tsimv')).first.presence ||
        Array(document['all_text_tsimv']).first.to_s
      next [] if text.blank?

      type = if filename.end_with?('.vtt') || format.include?('vtt') || format.include?('audio') || format.include?('video')
               'av'
             elsif filename.end_with?('.hocr') || format.include?('hocr') || format.include?('image')
               'image'
             else
               'pdf'
             end

      source_file_id = Array(document['related_url_tesim']).filter_map do |value|
        value.to_s[/source_file_set_id:([^,\s]+)/, 1]
      end.first

      result = {
        file_id: source_file_id.presence || file_id,
        label: (%w[av pdf].include?(type) && source_file_id.present? ? source_file_label(source_file_id, fallback: label) : label),
        text: text,
        type: type,
        query: query,
        regions: type == 'image' ? hocr_regions(document['hocr_markup'], query) : nil,
        region: nil,
        pages: type == 'pdf' ? pdf_pages_for_query(file_id, query) : []
      }
      regions = result.delete(:regions)
      result[:region] = regions&.fetch(:context)
      result[:word_region] = regions&.fetch(:word)
      if type == 'av'
        av_cue_results(result, document_id: file_id, query: query)
      elsif type == 'pdf'
        result.delete(:pages).map { |page| result.merge(page: page) }
      else
        [result]
      end
    end

    results = results.uniq do |result|
      [result[:type], result[:file_id], result[:start_time], result[:page], result[:region]]
    end

    {
      query: query,
      imageResults: results.select { |result| result[:type] == 'image' }.map { |result| search_result(result, viewer: 'images') },
      pdfResults: results.select { |result| result[:type] == 'pdf' }.map { |result| search_result(result, viewer: 'pdf') },
      avResults: results.select { |result| result[:type] == 'av' }.map { |result| search_result(result, viewer: 'ramp') }
    }
  end

  def search_result(result, viewer:)
    focus_param = result[:type] == 'pdf' ? 'pdf_file_id' : 'canvas_id'
    focus_value = result[:type] == 'pdf' ? result[:file_id] : "/canvas/#{result[:file_id]}"
    start_time = result[:start_time]
    time_param = start_time.present? ? "&t=#{start_time}" : ''
    region_param = result[:type] == 'image' && result[:region].present? ? "&xywh=#{ERB::Util.url_encode(result[:region])}" : ''
    word_region_param = result[:type] == 'image' && result[:word_region].present? ? "&word_xywh=#{ERB::Util.url_encode(result[:word_region])}" : ''
    page_param = result[:type] == 'pdf' && result[:page].present? ? "&page=#{result[:page]}&search=#{ERB::Util.url_encode(result[:query].to_s)}" : ''
    {
      fileSetId: result[:file_id],
      viewer: viewer,
      imageLabel: result[:label],
      pdfLabel: result[:label],
      mediaLabel: result[:label],
      imageUrl: nil,
      alt: result[:label],
      text: result[:text],
      startTime: start_time,
      timestamp: result[:timestamp],
      region: result[:region],
      wordRegion: result[:word_region],
      page: result[:page],
      search: result[:query],
      href: "#{request.path.sub(%r{/deep_search\z}, '')}?viewer=#{viewer}&#{focus_param}=#{ERB::Util.url_encode(focus_value)}#{time_param}#{region_param}#{word_region_param}#{page_param}"
    }
  end

  def pdf_pages_for_query(document_id, query)
    resource = Hyrax.query_service.find_by(id: Valkyrie::ID.new(document_id))
    file = Hyrax.config.file_set_file_service.new(file_set: resource).primary_file
    content = Hyrax.storage_adapter.find_by(id: file.file_identifier)&.stream&.read
    return if content.blank?

    Tempfile.create(['scholarspace-search', '.pdf']) do |pdf_file|
      pdf_file.binmode
      pdf_file.write(content)
      pdf_file.flush
      stdout, _stderr, status = Open3.capture3('pdftotext', '-layout', '-q', pdf_file.path, '-')
      next unless status.success?

      pages = stdout.split("\f")
      pages.each_index.filter_map do |index|
        index + 1 if pages[index].downcase.include?(query.downcase)
      end
    end
  rescue StandardError => e
    Rails.logger.debug("PDF search page lookup failed: #{e.class}: #{e.message}")
    nil
  end

  def hocr_regions(markup, query)
    document = Nokogiri::HTML(Array(markup).join(' '))
    boxes = document.css('span.ocrx_word, span.ocr_word').filter_map do |node|
      next unless node.text.downcase.include?(query.downcase)

      context_node = node.ancestors('.ocr_line').first || node
      context_coordinates = context_node['title'].to_s.match(/\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/i)
      word_coordinates = node['title'].to_s.match(/\bbbox\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/i)
      next unless context_coordinates && word_coordinates

      { context: context_coordinates.captures.map(&:to_i), word: word_coordinates.captures.map(&:to_i) }
    end
    return if boxes.empty?

    context = format_bbox(boxes.first[:context])
    word = format_bbox(boxes.first[:word])
    { context: context, word: word }
  end

  def format_bbox(bbox)
    x1, y1, x2, y2 = bbox
    "#{x1},#{y1},#{x2 - x1},#{y2 - y1}"
  end

  def av_cue_results(result, document_id:, query:)
    cues = matching_vtt_cues(vtt_content(document_id), query)
    return [result] if cues.empty?

    cues.map do |cue|
      result.merge(text: cue[:text], start_time: cue[:start_time], timestamp: cue[:timestamp])
    end
  end

  def matching_vtt_cues(content, query)
    content.to_s.gsub("\r\n", "\n").split(/\n{2,}/).filter_map do |block|
      lines = block.lines.map(&:strip)
      timestamp_index = lines.index { |line| line.include?('-->') }
      next unless timestamp_index

      text = lines.drop(timestamp_index + 1).join(' ').strip
      next unless text.downcase.include?(query.downcase)

      timestamp = lines[timestamp_index].split('-->').first.to_s.strip
      {
        text: text,
        start_time: vtt_timestamp_seconds(timestamp),
        timestamp: timestamp.sub(/\.\d+\z/, '')
      }
    end
  end

  def vtt_timestamp_seconds(timestamp)
    parts = timestamp.split(':').map(&:to_f)
    parts.reverse_each.with_index.sum { |part, index| part * (60**index) }
  end

  def vtt_content(document_id)
    resource = Hyrax.query_service.find_by(id: Valkyrie::ID.new(document_id))
    file = Hyrax.config.file_set_file_service.new(file_set: resource).primary_file
    Hyrax.storage_adapter.find_by(id: file.file_identifier)&.stream&.read.to_s
  rescue Valkyrie::Persistence::ObjectNotFoundError
    ''
  end

  def source_file_label(source_file_id, fallback:)
    resource = Hyrax.query_service.find_by(id: Valkyrie::ID.new(source_file_id))
    Array(resource.title).first.to_s.presence || fallback
  rescue Valkyrie::Persistence::ObjectNotFoundError
    fallback
  end
end