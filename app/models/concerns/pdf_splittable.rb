# frozen_string_literal: true

require 'open3'
require 'securerandom'
require 'tmpdir'

module PdfSplittable
  extend ActiveSupport::Concern
  include Enumerable

  COL_WIDTH = 3
  COL_HEIGHT = 4
  COL_COLOR_DESC = 5
  COL_CHANNELS = 6
  COL_BITS = 7
  COL_XPPI = 12

  # included do
  # end

  # class_methods do
  # end

  # "path" will be path to pdf

  def baseid
    SecureRandom.uuid
  end

  def tmpdir
    Dir.mktmpdir
  end

  def image_extension
    'tiff'
  end

  def compression
    'lzw'
  end

  def quality
    400
  end

  def gsdevice
    color, channels, bpc = pdfinfo.color
    device = nil
    if color == 'gray'
      # CCITT Group 4 Black and White, if applicable:
      if bpc == 1
        device = 'tiffg4'
        self.compression = 'g4'
      elsif bpc > 1
        # 8 Bit Grayscale, if applicable:
        device = 'tiffgray'
      end
    end

    # otherwise color:
    device = colordevice(channels, bpc) if device.nil?
    device
  end

  def colordevice(channels, bpc)
    bits = bpc * channels
    # will be either 8bpc/16bpd color TIFF,
    #   with any CMYK source transformed to 8bpc RBG
    bits = 24 unless [24, 48].include? bits
    "tiff#{bits}nc"
  end

  def gsconvert
    output_base = File.join(tmpdir, "#{baseid}-page%d.#{image_extension}")
    # NOTE: you must call gsdevice before compression, as compression is
    # updated during the gsdevice call.
    cmd = "gs -dNOPAUSE -dBATCH -sDEVICE=#{gsdevice} -dTextAlphaBits=4"
    cmd += " -sCompression=#{compression}" if compression?
    cmd += " -sOutputFile=#{output_base} -r#{quality} -f #{pdfpath}"
    filenames = []

    Open3.popen3(cmd) do |_stdin, stdout, _stderr, _wait_thr|
      page_number = 0
      stdout
        .read
        .split("\n")
        .each do |line|
          next unless line.start_with?('Page ')

          page_number += 1
          filenames << File.join(
            tmpdir,
            "#{baseid}-page#{page_number}.#{image_extension}"
          )
        end
    end

    filenames
  end

  def pdf_info
    @page_count = 0
    @color_description = 'gray'
    @width = 0
    @height = 0
    @channels = 0
    @bits = 0
    @pixels_per_inch = 0
    Open3.popen3(
      format('pdfimages -list %<path>s 2>/dev/null', path: path)
    ) do |_stdin, stdout, _stderr, _wait_thr|
      stdout
        .read
        .split("\n")
        .each_with_index do |line, index|
          # Skip the two header lines
          next if index <= 1

          @page_count += 1
          @cells = line.gsub(/\s+/m, ' ').strip.split(' ')

          @color_description = 'rgb' if cells[COL_COLOR_DESC] != 'gray'
          @width = cells[COL_WIDTH].to_i if cells[COL_WIDTH].to_i > @width
          cells[COL_HEIGHT].to_i if cells[COL_HEIGHT].to_i > @height
          @channels = cells[COL_CHANNELS].to_i if cells[COL_CHANNELS].to_i >
                                                  @channels
          @bits = cells[COL_BITS].to_i if cells[COL_BITS].to_i > @bits

          # In the case of poppler version < 0.25, we will have no more than 12 columns.  As such,
          # we need to do some alternative magic to calculate this.
          if page_count == 1 && cells.size <= 12
            pdf = MiniMagick::Image.open(path)
            width_points = pdf.width
            width_px = width
            @pixels_per_inch = (72 * width_px / width_points).to_i
          elsif cells[COL_XPPI].to_i > @pixels_per_inch
            # By the magic of nil#to_i if we don't have more than 12 columns, we've already set
            # the @pixels_per_inch and this line won't due much of anything.
            @pixels_per_inch = cells[COL_XPPI].to_i
          end
        end
    end

    {
      page_count: page_count,
      color_description: color_description,
      width: width,
      height: height,
      channels: channels,
      bits: bits,
      pixels_per_inch: pixels_per_inch
    }
  end
end
