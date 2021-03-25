class Datahub::Upvs::PublicAuthorityEdesk < DatahubRecord
  ICO_REGEXP = /\d+/

  def self.search(query)
    if query.match(ICO_REGEXP)
      where('cin::varchar ilike ?', "#{query}%").limit(15)
    else
      where('unaccent(name) ilike unaccent(?)', "%#{query}%").order('LENGTH(name) ASC').limit(15) # TODO make this better
    end
  end

  def serializable_hash(options = nil)
    super(options).merge(cin: cin.to_s.rjust(8, '0'))
  end
end
