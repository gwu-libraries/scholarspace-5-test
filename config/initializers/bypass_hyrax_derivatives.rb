# frozen_string_literal: true

# This is essentially just for short circuiting Hyrax derivative triggering
# there may be a better way to avoid that but for now this works.

module Hyrax
  module Listeners
    class FileListener
      def on_file_characterized(_event)
        nil
      end
    end
  end
end