module Searchable
  extend ActiveSupport::Concern
  include PgSearch::Model

  def to_search_str(str)
    Transliterator.transliterate(str&.downcase)
  end

  def html_to_search_str(str)
    to_search_str ActionView::Base.full_sanitizer.sanitize(str)&.gsub(/\R+/, ' ')&.gsub(/\s+/, ' ')&.strip
  end
end
