# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("node_modules")

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )

# Hyrax gem images are served from background jobs (e.g. ThumbnailPathService
# called during Solr indexing inside ValkyrieCharacterizationJob). They are not
# in app/assets/images so they are not picked up by the manifest link_tree
# directive and must be explicitly precompiled here.
Rails.application.config.assets.precompile += %w[
	default.png
	audio.png
	collection.png
	work.png
	unauthorized.png
	loading.gif
	progressbar.gif
]
