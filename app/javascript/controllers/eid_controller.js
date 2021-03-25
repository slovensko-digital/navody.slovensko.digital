import {Controller} from 'stimulus';

export default class extends Controller {
    start(event) {
        event.currentTarget.innerText = 'Prebieha prihlasovanie cez eID';
        event.currentTarget.classList.add('govuk-button--disabled');
        event.currentTarget.disabled = 'disabled'
        // TODO spinner class?
        // TODO timeout?
    }

    confirmRemoveSignatures(event) {
        const message = 'Ak správu chcete upraviť, musíte podpisy odstrániť. Chcete všetky podpisy naozaj ostrániť?';
        if (confirm(message)) {
            document.getElementById('submissions_general_agenda_signed_form_base64').value = '';
            Rails.fire(document.getElementById('new_message'), 'submit');
        } else {
            event.currentTarget.blur();
        }
        event.preventDefault();
        event.stopImmediatePropagation();
    }
}
