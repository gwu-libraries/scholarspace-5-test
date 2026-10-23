Rails.application.config.to_prepare do
  module ModelConverterPatch
    def graph_resource
      # If the resource is a nested resource with a hashed URI, we don't want to query Fedora for a URI formed from this resource ID, because it will return everything at the base_path, resulting in a unnecessary work (clearing out the graph)
      # Passing nil here returns an empty graph, which doesn't seem to cause problems
      s = resource.id.to_s.start_with?("#") ? nil : subject
      @graph_resource ||= ::Ldp::Container::Basic.new(connection, s, nil, base_path)
    end
  end
  Valkyrie::Persistence::Fedora::Persister::ModelConverter.prepend ModelConverterPatch
end
