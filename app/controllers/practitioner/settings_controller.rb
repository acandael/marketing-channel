class Practitioner::SettingsController < Practitioner::BaseController
  before_action :block_impersonator, only: :update

  def show
  end

  def update
    case params[:section]
    when "password"
      update_password
    when "email"
      request_email_change
    else
      redirect_to practitioner_settings_path, alert: "Unbekannter Einstellungsbereich."
    end
  end

  private

  def block_impersonator
    return unless Current.impersonating?
    redirect_to practitioner_settings_path,
                alert: "Sie können Kontoanmeldedaten nicht ändern, während Sie ein Konto stellvertretend nutzen."
  end

  def update_password
    unless Current.user.authenticate(params[:current_password].to_s)
      flash.now[:alert] = "Das aktuelle Passwort ist nicht korrekt."
      return render :show, status: :unprocessable_content
    end

    new_password = params[:new_password].to_s
    if new_password.length < 8
      flash.now[:alert] = "Das neue Passwort muss mindestens 8 Zeichen lang sein."
      return render :show, status: :unprocessable_content
    end
    if new_password != params[:new_password_confirmation].to_s
      flash.now[:alert] = "Die Passwortbestätigung stimmt nicht überein."
      return render :show, status: :unprocessable_content
    end

    Current.user.update!(password: new_password)
    redirect_to practitioner_settings_path, notice: "Passwort aktualisiert."
  end

  def request_email_change
    new_email = params[:new_email_address].to_s.strip.downcase
    unless new_email.match?(URI::MailTo::EMAIL_REGEXP)
      flash.now[:alert] = "Bitte geben Sie eine gültige E-Mail-Adresse an."
      return render :show, status: :unprocessable_content
    end

    if User.active.where.not(id: Current.user.id).exists?(email_address: new_email)
      flash.now[:alert] = "Diese E-Mail-Adresse wird bereits verwendet."
      return render :show, status: :unprocessable_content
    end

    Current.user.start_email_change!(new_email)
    EmailChangeMailer.with(user: Current.user).confirm.deliver_later

    redirect_to practitioner_settings_path,
                notice: "Prüfen Sie #{new_email} auf einen Bestätigungslink. Er ist 24 Stunden gültig."
  end
end
