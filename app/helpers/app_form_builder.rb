class AppFormBuilder < ActionView::Helpers::FormBuilder

  def text_field(method, options = {})
    group_classes = ['govuk-form-group']
    field_classes = ['govuk-input', options[:class]]
    described_by = []

    label = options.delete(:label)
    label = label(method, label, class: 'govuk-label') if label

    hint = options.delete(:hint)
    if hint
      hint = @template.content_tag(:span, hint, id: hint_id(method), class: 'govuk-hint')
      described_by << hint_id(method)
    end

    if @object.errors[method].present?
      group_classes << 'govuk-form-group--error'
      field_classes << 'govuk-input--error'
      described_by << error_id(method)
    end

    options = options.merge({'aria-describedby': described_by.join(' ')}) unless described_by.empty?

    @template.content_tag(:div, class: group_classes) do
      @template.concat label
      @template.concat hint
      @template.concat error_message(method)
      @template.concat super(method, objectify_options(options.merge({class: field_classes})))
    end
  end

  def radio_button(method, tag_value, options = {})
    field_classes = ['govuk-radios__input', options[:class]]
    radio_method = method.to_s + "_" + tag_value

    label = options.delete(:label)
    strong_label = options.delete(:strong_label)
    label_classes = ['govuk-label', 'govuk-radios__label']
    label_classes << 'govuk-label--s' if strong_label
    label = label(radio_method, label, class: label_classes) if label

    hint = options.delete(:hint)
    hint = @template.content_tag(:span, hint, id: hint_id(radio_method), class: 'govuk-hint govuk-radios__hint') if hint
    options = options.merge({'aria-describedby': hint_id(radio_method)}) if hint

    @template.content_tag(:div, class: 'govuk-radios__item') do
      @template.concat super(method, tag_value, objectify_options(options.merge({class: field_classes})))
      @template.concat label
      @template.concat hint
    end
  end

  def radios(method, text, options = {}, &block)
    radios_div = @template.content_tag(:div, class: 'govuk_radios', id: "#{@object.model_name.singular}_#{method}") do
      @template.concat @template.capture(&block)
    end
    radios_fs = field_set(method, text, options) do
      @template.concat radios_div
    end

    classes = 'govuk-form-group'
    classes = classes + ' govuk-radios--inline' if options[:inline]
    classes = classes + ' govuk-form-group--error' if @object.errors[method].present?
    @template.content_tag(:div, class: classes) do
      @template.concat radios_fs
    end
  end


  def field_set(method, text, options = {}, &block)
    legend = @template.content_tag(:legend, {class: 'govuk-fieldset__legend govuk-fieldset__legend--xl'}) do
      @template.concat @template.content_tag(:h2, text, class: 'govuk-fieldset__heading')
    end

    described_by = []
    hint = options.delete(:hint)
    if hint
      hint = @template.content_tag(:span, hint, id: hint_id(method), class: 'govuk-hint')
      described_by << hint_id(method)
    end

    if @object.errors[method].present?
      described_by << error_id(method)
    end

    fs_options = {class: 'govuk-fieldset'}
    fs_options = fs_options.merge({'aria-describedby': described_by.join(' ')}) unless described_by.empty?

    @template.content_tag(:fieldset, fs_options) do
      @template.concat legend
      @template.concat hint
      @template.concat error_message(method)
      @template.concat @template.capture(&block)
    end

  end

  def submit(value = nil, options = {})
    super(value, objectify_options(options.merge({class: ['govuk-button', options[:class]]})))
  end

  def error_message(method)
    errors = @object.errors[method]
    return nil unless errors.any?

    @template.content_tag :span, id: error_id(method), class: 'govuk-error-message' do
      @template.concat @template.content_tag(:span, 'Chyba: ', class: 'govuk-visually-hidden')
      @template.concat errors.join('. ')
    end
  end

  def error_id(method)
    @object.errors[method].present? ? @object_name + '_' + method.to_s + '-error' : ''
  end

  def hint_id(method)
    @object_name + '_' + method.to_s + '-hint'
  end
end
