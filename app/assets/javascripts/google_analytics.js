$(document).on('turbolinks:load', function () {
    if (typeof ga === 'function') {
        ga('set', 'location', event.data.url);
        ga('send', 'pageview');
    }

  $('#ga-feedback-useful').click(function () {
    sendGoogleAnalytics('Useful');
  });

  $('#ga-feedback-not-useful').click(function () {
    sendGoogleAnalytics('Not Useful');
  });

  $('#ga-feedback-bug-report').click(function () {
    sendGoogleAnalytics('Bug Report');
  });
});

function sendGoogleAnalytics(feedbackType) {
  if (typeof ga === 'function') {
    ga('send', 'event', 'Feedback', feedbackType);
  }
}
