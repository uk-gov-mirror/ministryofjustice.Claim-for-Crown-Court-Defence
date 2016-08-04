class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception unless ENV['DISABLE_CSRF'] == '1'

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Excluding some endpoints due to ELB only talking HTTP on port 80 and not following redirects to https.
  force_ssl except: [:ping, :healthcheck], if: :ssl_enabled?

  helper_method :current_user_messages_count
  helper_method :signed_in_user_profile_path
  helper_method :current_user_persona_is?

  load_and_authorize_resource

  unless Rails.env.development?
    rescue_from Exception do |exception|
      if exception.is_a?(ActiveRecord::RecordNotFound)
        redirect_to error_404_url
      else
        Raven.capture_exception(exception) if Rails.env.production?
        redirect_to error_500_url
      end
    end
  end

  rescue_from CanCan::AccessDenied do |_exception|
    redirect_to root_path_url_for_user, alert: 'Unauthorised'
  end

  def user_for_paper_trail
    current_user.nil? ? 'Unknown' : current_user.persona.class.to_s.humanize
  end

  def current_user_messages_count
    UserMessageStatus.for(current_user).not_marked_as_read.count
  end

  def current_user_persona_is?(persona_class)
    current_user.persona.is_a?(persona_class)
  end

  def signed_in_user_profile_path
    path_helper_method = "#{current_user.persona.class.to_s.underscore.pluralize}_admin_#{current_user.persona.class.to_s.underscore}_path"
    send path_helper_method, current_user.persona_id
  end

  def root_path_url_for_user
    if current_user
      method_name = "after_sign_in_path_for_#{current_user.persona.class.to_s.underscore.downcase}"
      send(method_name)
    else
      new_user_session_url
    end
  end

  def after_sign_out_path_for(_resource, params={})
    if Rails.env.development? || Rails.env.devunicorn? || RailsHost.demo? || RailsHost.dev?
      new_user_session_url
    else
      new_feedback_url(params.merge(type: 'feedback'))
    end
  end

  def after_sign_in_path_for(_resource)
    method_name = "after_sign_in_path_for_#{current_user.persona.class.to_s.underscore.downcase}"
    send(method_name)
  end

  private

  def ssl_enabled?
    Rails.env.production?
  end

  def after_sign_in_path_for_super_admin
    super_admins_root_url
  end

  def after_sign_in_path_for_external_user
    external_users_root_url
  end

  def after_sign_in_path_for_case_worker
    if current_user.persona.admin?
      case_workers_admin_root_url
    else
      case_workers_root_url
    end
  end

  def method_missing(method, *args)
    if method.to_s =~ /after_sign_in_path_for_(.*)/
      raise "Unrecognised user type #{$1}"
    end
    super
  end

  def track_visit(*args)
    (flash.now[:ga] ||= []) << GoogleAnalytics::DataLayer.new(:virtual_page, *args)
  end

end
