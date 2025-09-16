# frozen_string_literal: true
require "rtesseract"

module Hydra::Derivatives::Processors
  class Image < Processor
    class_attribute :timeout

    def process
      timeout ? process_with_timeout : create_resized_image
      timeout ? process_with_timeout : create_ocr_docs
    end

    def process_with_timeout
      Timeout.timeout(timeout) { create_resized_image }
    rescue Timeout::Error
      raise Hydra::Derivatives::TimeoutError,
            "Unable to process image derivative\nThe command took longer than #{timeout} seconds to execute"
    end

    protected

    # When resizing images, it is necessary to flatten any layers, otherwise the background
    # may be completely black. This happens especially with PDFs. See #110
    def create_resized_image
      create_resized_image_with_imagemagick
    end

    def create_resized_image_with_imagemagick
      Hydra::Derivatives::Logger.debug(
        "[ImageProcessor] Using ImageMagick image resize method"
      )
      create_image do |temp_file|
        if size
          temp_file.flatten
          temp_file.resize(size)
        end
      end
    end

    # rubocop:enable Metrics/MethodLength

    def create_image
      xfrm = selected_layers(load_image_transformer)
      yield(xfrm) if block_given?
      xfrm.format(directives.fetch(:format))
      xfrm.quality(quality.to_s) if quality
      write_image(xfrm)
    end

    def write_image(xfrm)
      output_io = StringIO.new
      xfrm.write(output_io)
      output_io.rewind
      output_file_service.call(output_io, directives)
    end

    # Override this method if you want a different transformer, or need to load the
    # raw image from a different source (e.g. external file)
    def load_image_transformer
      MiniMagick::Image.open(source_path)
    end

    def create_ocr_docs
      ocr_doc = load_ocr_doc
      yield(ocr_doc) if block_given?
      write_ocr_doc(ocr_doc)
    end

    def write_ocr_doc(ocr_doc)
      output_io = StringIO.new

      result = require "pry"
      binding.pry

      # output_file_service.call(output_io, directives)
    end

    def load_ocr_doc
      RTesseract.new(source_path)
    end

    private

    def size
      directives.fetch(:size, nil)
    end

    def quality
      directives.fetch(:quality, nil)
    end

    def selected_layers(image)
      if /pdf/i.match?(image.type)
        image.layers[directives.fetch(:layer, 0)]
      elsif directives.fetch(:layer, false)
        image.layers[directives.fetch(:layer)]
      else
        image
      end
    end
  end
end
