# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Hybrid setup:
# - Sprockets compiles engine/application assets (Hyrax/Blacklight CSS+JS)
# - Shakapacker compiles custom JS bundles (e.g., React)
Rails.application.config.assets.precompile = %w(
	application.css
	application.js
	*.png *.jpg *.jpeg *.gif *.svg *.ico *.woff *.woff2 *.ttf *.eot
)

# Precompile additional assets as needed.
# Rails.application.config.assets.precompile += %w( admin.ico )
