class Admin::PagesController < Admin::AdminController
  before_action :set_page, only: [:show, :edit, :update, :destroy]

  # GET /pages
  def index
    @pages = Page.all
  end

  # GET /pages/1
  def show
  end

  # GET /pages/new
  def new
    @page = Page.new
  end

  # GET /pages/1/edit
  def edit
  end

  # POST /pages
  def create
    @page = Page.new(page_params)

    if @page.save
      redirect_to admin_pages_url, notice: 'Page was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /pages/1
  def update
    if @page.update(page_params)
      redirect_to admin_pages_url, notice: 'Page was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /pages/1
  def destroy
    @page.destroy
    redirect_to admin_pages_url, notice: 'Page was successfully destroyed.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_page
    @page = Page.find_by(slug: params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def page_params
    params.require(:page).permit(:title, :keywords, :content, :slug, :is_faq, :is_searchable, :position, :image_name)
  end
end
