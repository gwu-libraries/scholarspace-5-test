Rails.application.config.to_prepare do
  module Hyrax
    module EmbargoManagerDecorator
      module ClassMethods
        def create_or_update_embargo_on_members(members, work)
              # TODO: account for all members and levels, not just file sets. ref: #6131
              members.each do |member|
                # reload member to make sure nothing in the transaction has changed it already
                member = Hyrax.query_service.find_by(id: member.id)
                member_embargo_needs_updating = work.embargo.updated_at > member.embargo&.updated_at if member.embargo

                if member.embargo
                  if member_embargo_needs_updating
                    member.embargo.embargo_release_date = work.embargo['embargo_release_date']
                    member.embargo.visibility_during_embargo = work.embargo['visibility_during_embargo']
                    member.embargo.visibility_after_embargo = work.embargo['visibility_after_embargo']
                    member.embargo = Hyrax.persister.save(resource: member.embargo)

                  end
                else
                  work_embargo_manager = Hyrax::EmbargoManager.new(resource: work)
                  work_embargo_manager.copy_embargo_to(target: member)
                  member = Hyrax.persister.save(resource: member)
                end

                user ||= ::User.find_by_user_key(member.depositor)
                # the line below works in that it indexes the file set with the necessary lease properties
                # I do not know however if this is the best event_id to pass
                Hyrax.publisher.publish('object.metadata.updated', object: member, user: user)
              end
            end
          # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
        end
        def self.prepended(mod)
          mod.singleton_class.prepend(ClassMethods)
        end
      end
    end
    Hyrax::EmbargoManager.prepend Hyrax::EmbargoManagerDecorator
  end
