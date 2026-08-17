# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberQueries do
  let(:query_class) do
    Class.new do
      include MemberQueries
    end
  end

  let(:query) { query_class.new }

  describe "#find_member_by_id" do
    it "returns the member from the Hyrax query service" do
      member = instance_double("FileSet")

      allow(Hyrax.query_service).to receive(:find_by).with(id: "member-1").and_return(member)

      expect(query.find_member_by_id("member-1")).to eq(member)
    end

    it "returns nil when the member cannot be found" do
      allow(Hyrax.query_service)
        .to receive(:find_by)
        .with(id: "missing-member")
        .and_raise(Valkyrie::Persistence::ObjectNotFoundError)

      expect(query.find_member_by_id("missing-member")).to be_nil
    end
  end

  describe "#find_storage_file_by_id" do
    it "returns the file from the Hyrax storage adapter" do
      storage_file = instance_double("Valkyrie::StorageAdapter::File")

      allow(Hyrax.storage_adapter).to receive(:find_by).with(id: "file-1").and_return(storage_file)

      expect(query.find_storage_file_by_id("file-1")).to eq(storage_file)
    end
  end
end