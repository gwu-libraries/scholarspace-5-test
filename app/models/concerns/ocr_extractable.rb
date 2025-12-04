# frozen_string_literal: true

require 'open3'
require 'tmpdir'

module OcrExtractable
  extend ActiveSupport::Concern

  # included do
  # end

  # class_methods do
  # end

  def im_identify
    # cmd = "identify"

    # cmd += " -format 'Geometry: %G\nDepth: %[bit-depth]\nColorspace: %[colorspace]\nAlpha: %A\nMIME type: %m\n' #{path}"

    # output, status = Open3.capture2(cmd)
    # Rails.logger.info "Identify command output: #{output}"
    # Rails.logger.info "Identify command status: #{status}"
    # output.lines
  end

  def image_metadata
    # result = {}
    # lines = im_identify
    # result[:width], result[:height] = im_identify_geometry(lines)
    # result[:content_type] = im_mime(lines)
    # populate_im_color!(lines, result)
    # result
  end

  def preprocess_image
    # tool = IiifPrint::ImageTool.new(path)  # just set to like magik
    # return if tool.metadata[:color] == 'monochrome'
    # intermediate_path = File.join(Dir.mktmpdir, 'monochrome-interim.tif')
    # tool.convert(intermediate_path, true)
    # @path = intermediate_path
  end

  def run_ocr
    # outfile = File.join(Dir.mktmpdir, 'output_html')
    # cmd = "OMP_THREAD_LIMIT=1 tesseract #{path} #{outfile}"
    # cmd += " #{tesseract_options}" if tesseract_options.present?
    # cmd += " hocr"
    # `#{cmd}`
    # outfile + '.hocr'
  end
end
