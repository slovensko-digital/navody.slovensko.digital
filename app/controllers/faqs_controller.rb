class FaqsController < ApplicationController
  def index
    @pages = Page.faq.order(position: :asc)
  end

  def show
    @page = Page.faq.find_by_slug(params[:id])
  end
end
