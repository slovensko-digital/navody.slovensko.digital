require 'rails_helper'

RSpec.describe PgSearch::Document, type: :model do

  subject { described_class.search(query) }

  let(:query) { 'Batman' }

  describe 'search' do
    context 'priority search' do
      it 'has bigger priority for title' do
        page2 = create(:page, is_faq: true, content: query)
        page1 = create(:page, is_faq: true, title: query)
        expect(subject.collect(&:searchable)).to eq [page1, page2]
      end

      it 'has bigger priority for keyword' do
        page2 = create(:page, is_faq: true, content: query)
        page1 = create(:page, is_faq: true, keywords: query)
        expect(subject.collect(&:searchable)).to eq [page1, page2]
      end
    end

    context 'any word' do
      let(:query) { 'Batman Superman' }
      it 'matches both query words' do
        page2 = create(:page, is_faq: true, title: 'Batman')
        page1 = create(:page, is_faq: true, title: 'Superman')
        expect(subject.collect(&:searchable)).to match_array [page1, page2]
      end
    end

    context 'prefix' do
        it 'does not match prefixed word' do
        create(:page, is_faq: true, title: 'Batmanized')
        expect(subject.collect(&:searchable)).to be_empty
      end
    end

    context 'doc length normalization' do
      it 'will not penalize by document lengths' do
        page2 = create(:page, is_faq: true, title: (query+' ') * 20)
        page1 = create(:page, is_faq: true, title: (query+' ') * 5)
        expect(subject.collect(&:searchable)).to eq [page2, page1]
      end
    end
  end

  describe 'reposition_all' do
    it 'updates positions for featurable featured docs by existing position order' do
      j1 = create(:journey, title: 'journey1')
      j2 = create(:journey, title: 'journey2')
      j3 = create(:journey, title: 'journey3')
      j4 = create(:journey, title: 'journey4')
      d1 = PgSearch::Document.where(searchable: j1).first
      d2 = PgSearch::Document.where(searchable: j2).first
      d3 = PgSearch::Document.where(searchable: j3).first
      d4 = PgSearch::Document.where(searchable: j4).first
      d1.update!(featured: true, featured_position: 50)
      d2.update!(featured: true, featured_position: 25)
      d3.update!(featured: true, featured_position: 1)
      expect(d4.reload.featured_position).to eq 0

      described_class.reposition_all

      expect(d1.reload.featured_position).to eq 3
      expect(d2.reload.featured_position).to eq 2
      expect(d3.reload.featured_position).to eq 1
      # non-featured is not changed.
      expect(d4.reload.featured_position).to eq 0
    end
  end
end
