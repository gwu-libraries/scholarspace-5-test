# frozen_string_literal: true

class AddUniqueConstraintToPermissionTemplateAccesses < ActiveRecord::Migration[5.2]
  def change
    add_index :permission_template_accesses,
              %i[permission_template_id agent_id agent_type access],
              unique: true,
              name: 'uk_permission_template_accesses'
  end
end
