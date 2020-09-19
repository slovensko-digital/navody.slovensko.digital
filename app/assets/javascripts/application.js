// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, or any plugin's
// vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file. JavaScript code in this file should be added after the last require_* statement.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require jquery
//= require activestorage
//= require turbolinks
//= require cookieconsent.min
//= require newsletter_sign_up
//= require google_analytics

$(document).on('turbolinks:load', function () {
    // Initialize Cookie Bar
    window.cookieconsent.initialise({
        "palette": {
            "popup": {
                "background": "#1d1e21"
            },
            "button": {
                "background": "#4cae18"
            }
        },
        "theme": "classic",
        "content": {
            "message": "Tento web používa súbory cookie na poskytovanie služieb a analýzu webu. Používaním tohto webu vyjadrujete svoj súhlas s používaním súborov cookie.",
            "dismiss": "OK"
        },
        "showLink": false
    })
});
