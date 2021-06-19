/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb


// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
import '../application.sass'
import 'controllers'
import { initAll } from 'navody-digital-frontend'

(function() {
    var navody_digital_loaded = false;
    document.addEventListener('turbolinks:load', function () {
        if (navody_digital_loaded) {
            // When page is cached and then loaded from cache, links are generated again if there are already
            // links generated in cache, workaround is to remove previously generated links. Full solution would be
            // to put check into 'navody-digital-frontend' and do not generate if links already exist. Similar
            // turbolinks issue: https://stackoverflow.com/questions/40660288/turbolinks-duplicating-rich-text-editor
            document.querySelectorAll('.govuk-accordion__controls').forEach(e => e.remove());
        }
        initAll();
        navody_digital_loaded = true;
    });
})();



