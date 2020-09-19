module NotificationSubscriptionsHelper
  def render_notification_subscription_component(subscription_types, journey: nil, content: nil, &block)
    content = capture(&block) if block_given?
    group = NotificationSubscriptionGroup.new(subscription_types: subscription_types)
    group.user = current_user
    group.journey = journey
    render partial: 'notification_subscriptions/component', locals: {group: group, content: content}
  end
end
