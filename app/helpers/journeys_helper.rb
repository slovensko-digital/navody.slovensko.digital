module JourneysHelper
  def how_to_json_ld(journey)
    {
      '@context' => 'http://schema.org',
      '@type' => 'HowTo',
      'description' => sanitize_description(journey.description).to_str,
      'image' => image_url("journeys/#{journey.image_name}"),
      'name' => journey.title,
      'step' => journey.steps.map.with_index(1) do |step, idx|
        {
          '@type' => 'HowToStep',
          'name' => step.title,
          'url' => url_for([journey, step, only_path: false]),
          'position' => idx,
          'text' => sanitize_description(step.description, length: 100),
          'image' => image_url("steps/step-#{idx.to_s.rjust(2, '0')}.png"),
          'itemListElement' => step.tasks.map.with_index(1) do |task, step_idx|
            {
              '@type' => 'HowToDirection',
              'text' => task.title,
              'position' => step_idx
            }
          end
        }
      end
    }.to_json
  end
end
