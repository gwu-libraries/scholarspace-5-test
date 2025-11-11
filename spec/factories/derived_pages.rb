# frozen_string_literal: true

FactoryBot.define do
  factory :derived_page, class: "DerivedPage" do
    to_create do |obj|
      Hyrax.persister.save!(resource: obj)
      Hyrax.index_adapter.save(resource: obj)
    end

    transient do
      user {}
      # Set to true (or a hash) if you want to create an admin set
      with_admin_set { false }
    end

    # It is reasonable to assume that a work has an admin set; However, we don't want to
    # go through the entire rigors of creating that admin set.
    before(:create) do |work, evaluator|
      if evaluator.with_admin_set
        attributes = {}
        attributes[:id] = work.admin_set_id if work.admin_set_id.present?
        attributes =
          evaluator.with_admin_set.merge(
            attributes
          ) if evaluator.with_admin_set.respond_to?(:merge)
        admin_set = create(:admin_set, attributes)
        work.admin_set_id = admin_set.id
      end
    end

    after(:create) do |work, _evaluator|
      if work.try(:member_of_collections) && work.member_of_collections.present?
        work.save!
      end
    end

    title { ["Test title"] }
    representative_id { "12345-6789" }

    after(:build) do |work, evaluator|
      if work.try(:apply_depositor_metadata, evaluator.user.user_key)
        work.apply_depositor_metadata(evaluator.user.user_key)
      end
    end
  end
end
