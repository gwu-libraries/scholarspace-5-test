# frozen_string_literal: true

module Constants
  module FileExtensionConstants
    AV_EXTENSIONS = %w[mp3 wav m4a aac flac ogg oga mp4 m4v mov avi mkv webm mpeg mpg].freeze
    IMAGE_EXTENSIONS = %w[jpg jpeg png gif tif tiff webp jp2].freeze

    AV_EXTENSIONS_WITH_DOT = AV_EXTENSIONS.map { |extension| ".#{extension}" }.freeze
    IMAGE_EXTENSIONS_WITH_DOT = IMAGE_EXTENSIONS.map { |extension| ".#{extension}" }.freeze
  end
end