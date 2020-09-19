module FormatDaysHelper
  def format_remaining_days(remaining_days)
    # TODO use https://github.com/svenfuchs/rails-i18n
    if remaining_days > 4
      "Na túto možnosť ostáva ešte #{remaining_days} dní."
    elsif remaining_days > 1
      "Ostávajú už len #{remaining_days} dni."
    elsif remaining_days == 1
      "Ostáva už len 1 deň."
    elsif remaining_days == 0
      "Dnes je posledný možný termín."
    end
  end
end


