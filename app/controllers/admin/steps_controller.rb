class Admin::StepsController < Admin::AdminController
  before_action :set_journey
  before_action :set_step, only: [:edit, :update, :destroy, :reposition]

  # GET /steps
  def index
    @steps = @journey.steps.all
  end

  # GET /steps/new
  def new
    @step = @journey.new_step
  end

  # GET /steps/1/edit
  def edit
  end

  # POST /steps
  def create
    @step = @journey.steps.new(step_params)

    if @step.save
      redirect_to admin_journey_steps_url(@step.journey), notice: 'Step was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /steps/1
  def update
    if @step.update(step_params)
      redirect_to admin_journey_steps_url(@step.journey), notice: 'Step was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /steps/1
  def destroy
    recently_active_steps = @step.user_steps
                               .where('updated_at > ?', 1.month.ago)
                               .where.not('status in (?)', ['done', 'not_started'])
    recently_active_tasks = @step.user_tasks.where('user_tasks.updated_at > ?', 1.month.ago)

    if (recently_active_steps.any? || recently_active_tasks.any?) && params[:confirmed] != 'true'
      respond_to do |format|
        format.js
      end
    else
      @step.destroy
      redirect_to admin_journey_steps_url(@step.journey), notice: 'Step was successfully destroyed.'
    end
  end

  # POST /steps/1/reposition
  def reposition
    @step.reposition
    redirect_to admin_journey_step_tasks_path(@step.journey, @step), notice: 'Steps tasks were successfully repositioned.'
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_journey
    @journey = Journey.find_by!(slug: params[:journey_id])
  end

  def set_step
    @step = @journey.steps.find_by!(slug: params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def step_params
    params.require(:step).permit(
        :journey_id,
        :title,
        :custom_title,
        :keywords,
        :is_waiting_step,
        :slug,
        :description,
        :position,
        :app_url,
        :app_link_text,
        :type
    )
  end
end
