# frozen_string_literal: true

# This migration comes from iiif_print (originally 20231110163052)
class AddModelDetailsToIiifPrintPendingRelationships < ActiveRecord::Migration[
  5.2
]
  def change
    unless column_exists?(:iiif_print_pending_relationships, :parent_model)
      add_column :iiif_print_pending_relationships, :parent_model, :string
    end
    unless column_exists?(:iiif_print_pending_relationships, :child_model)
      add_column :iiif_print_pending_relationships, :child_model, :string
    end
    return if column_exists?(:iiif_print_pending_relationships, :file_id)

    add_column :iiif_print_pending_relationships, :file_id, :string
  end
end
