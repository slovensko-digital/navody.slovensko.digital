class Step < ApplicationRecord
  self.inheritance_column = 'type2' # TODO: remove this when all STI types are defined

  include Searchable

  belongs_to :journey
  has_many :tasks, dependent: :destroy
  has_many :user_steps, dependent: :destroy
  has_many :user_tasks, through: :user_steps


  after_commit :update_journey_search

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
  validates :is_waiting_step, inclusion: { in: [true, false] }

  # FIXME: fill in position from id!

  default_scope { order(position: :asc, id: :asc) }
  scope :published, -> do
    joins(:journey)
      .where(journeys: { published_status: 'PUBLISHED' })
  end

  multisearchable against: %i(description_search),
                  if: :published?,
                  additional_attributes: -> (step) {
                    { title: step.title_search,
                      keywords: step.keywords_search }
                  }

  def published?
    journey.published_status == 'PUBLISHED'
  end

  def has_app?
    type == 'ExternalAppStep'
  end

  def to_param
    slug
  end

  def next_step
    journey.steps.where('position > ?', position).order(position: :asc).first
  end

  def new_task
    new_position = tasks.empty? ? 1 : tasks.last.position + 1
    tasks.new(position: new_position)
  end

  def title_search
    to_search_str title
  end

  def description_search
    html_to_search_str description
  end

  def keywords_search
    to_search_str keywords
  end

  def reposition
    tasks.each_with_index do |task, index|
      task.position = index + 1
      task.save
    end
  end

  private

  def update_journey_search
    journey.update_pg_search_document
  end
end
