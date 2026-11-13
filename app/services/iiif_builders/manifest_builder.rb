# frozen_string_literal: true

class IiifBuilders::ManifestBuilder
  def self.manifest_for(presenter:, viewer: nil)
    new.manifest_for(presenter: presenter, viewer: viewer)
  end

  def self.manifest_json_for(presenter:, viewer: nil)
    new.manifest_json_for(presenter: presenter, viewer: viewer)
  end

  def manifest_for(presenter:, viewer: nil)
    builder_for(viewer).manifest_for(presenter: presenter)
  end

  def manifest_json_for(presenter:, viewer: nil)
    builder_for(viewer).manifest_json_for(presenter: presenter)
  end

  private

  def builder_for(viewer)
    case viewer.to_s
    when 'ramp'
      IiifBuilders::Ramp.new
    else
      IiifBuilders::Clover.new
    end
  end
end
