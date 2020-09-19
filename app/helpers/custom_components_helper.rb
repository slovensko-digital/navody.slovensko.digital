module CustomComponentsHelper
  def raw_with_custom_components(html, journey: nil)
    fragment = Nokogiri::HTML.fragment(html)

    fragment.css('embedded-app').each do |elm|
      elm.replace render_embedded_app(elm)
    end

    fragment.css('notification-subscription').each do |elm|
      subscription_types = elm[:types].split(/[,\s]+/)
      elm.replace render_notification_subscription_component(subscription_types, journey: journey, content: elm.inner_html)
    end

    fragment.css('deadline').each do |elm|
      deadline = Date.parse(elm[:time])
      elm.replace(render 'components/deadline', time: deadline, inner_html: elm.inner_html)
    end

    raw(fragment.to_s)
  end

  private

  def render_embedded_app(fragment)
    app_id = fragment['app-id']
    # TODO why is this hardcoded?
    if app_id == 'narodenie-rodny-list'
      render partial: 'components/embedded_app', locals: {app_id: app_id, template: 'apps/child_birth_app/picking_up_protocol/start'}
    else
      'error'
    end
  end
end
