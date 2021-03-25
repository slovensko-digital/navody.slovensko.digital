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
import {initAll} from 'navody-digital-frontend'
import accessibleAutocomplete from 'accessible-autocomplete'

function debounce(fn, delay) {
    let timer = null;
    return function () {
        let context = this, args = arguments;
        clearTimeout(timer);
        timer = setTimeout(function () {
            fn.apply(context, args);
        }, delay);
    };
}

function initAU() {
    document.getElementById('submissions_general_agenda_recipient_name').parentElement.remove();

    accessibleAutocomplete({
        element: document.getElementById('recipient-name-container'),
        id: 'submissions_general_agenda_recipient_name', // To match it to the existing <label>.
        source: debounce(async (query, populateResults) => {
            const res = await fetch(`/datahub/upvs/public_authority_edesks/search?q=${encodeURIComponent(query)}`);
            const data = await res.json();

            populateResults(data);
        }),
        onConfirm: (result) => {
            document.getElementById('submissions_general_agenda_recipient_uri').value = result?.uri;
        },
        minLength: 3,
        templates: {
            inputValue: (result) => {
                return result?.name
            },
            suggestion: (result) => {
                return `<strong>${result?.name}</strong> IČO: ${result?.cin}`
            }
        },
        confirmOnBlur: false,
        showNoOptionsFound: false,
        displayMenu: 'overlay',
        defaultValue: document.getElementById('recipient_name_default').value,
        tNoResults: () => 'Žiadne výsledky',
    })
}

document.addEventListener('turbolinks:load', function () {
    // Initialize GovUK/Navody-frontend Javascript
    initAll();

    initAU();
});

window.initAU = initAU;
