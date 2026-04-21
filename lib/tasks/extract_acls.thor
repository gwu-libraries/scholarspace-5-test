require 'thor'
require 'uri'
require 'json'

class Troubleshooting < Thor
  desc "extract JSON_FILE", "extract access controls to file"
  def extract(filepath)
    parser = URI::Parser.new()
    acls = Hyrax.query_service.find_all_of_model(model: Hyrax::AccessControl)
    uris = acls.map do |acl|
      acl_uri = parser.unescape(Hyrax.query_service.adapter.id_to_uri(acl.id).to_s)
      work_uri = parser.unescape(Hyrax.query_service.adapter.id_to_uri(acl.access_to).to_s)
      work = Hyrax.query_service.find_by(id: acl.access_to)
      work_title = work.title.join("")
      work_creator = work.creator.join("")
      permission_uris = acl.permissions.map do |permission|
        parser.unescape(Hyrax.query_service.adapter.id_to_uri(permission.id).to_s)
      end
      {acl: acl_uri, work: work_uri, title: work_title, creator: work_creator, permissions: permission_uris}
    end
    File.open(filepath, 'w') do |f|
      f.write(uris.to_json)
    end
  end
end
