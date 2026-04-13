module PagePacksHelper
  def add_page_js_pack(*packs)
    @page_js_packs = (Array(@page_js_packs) + packs.flatten.compact.map(&:to_s)).uniq
  end

  def add_page_css_pack(*packs)
    @page_css_packs = (Array(@page_css_packs) + packs.flatten.compact.map(&:to_s)).uniq
  end

  def shakapacker_manifest_available?
    Shakapacker.config.manifest_path.exist?
  end

  def render_page_pack_tags
    return "".html_safe unless shakapacker_manifest_available?

    page_css_packs = Array(@page_css_packs).map(&:to_s).uniq
    page_js_packs = Array(@page_js_packs).map(&:to_s).uniq
    tags = []

    tags << stylesheet_pack_tag(*page_css_packs) if page_css_packs.present?
    tags << javascript_pack_tag(*page_js_packs, defer: true) if page_js_packs.present?

    safe_join(tags, "\n")
  end
end
