require "uri"
require "net/http"

class FeedbacksController < ApplicationController
  def create
    respond_to do |format|
      if verify_recaptcha
        Net::HTTP.post_form(URI.parse('https://docs.google.com/forms/d/e/1FAIpQLSeZb9UvcF8JZ2-beCa1zMMjjwngbdV8UHAf-YQh-RDKnLrWMw/formResponse'), {
          'entry.1152016273': params[:current_path],
          'entry.366340186': params[:feedback_type],
          'entry.165514296': params[:not_useful_detail],
          'entry.593259938': params[:email],
          'entry.1623207670': params[:bug_what_were_you_doing],
          'entry.480582804': params[:bug_what_went_wrong],
        })
        @message = 'Váš podnet bol odoslaný. Ďakujeme.'
      else
        @message = 'Prosím, potvrďte, že nie ste robot.'
      end
      format.js
    end
  end
end
