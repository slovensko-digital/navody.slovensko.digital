class Submissions::SignedForm
  include ActiveModel::Model

  attr_accessor :form
  attr_accessor :signatures

  def self.parse(base64)
    new(form: OpenStruct.new(subject: 'podpisany nadpis', body: 'podpisane telo'), signatures: ['Ján Suchal, Púpavová 31, 841 04 Bratislava', 'Jozef Baklažán, Zeleninková 54, 841 05 Popudlivé močidlany'])
  end
end
