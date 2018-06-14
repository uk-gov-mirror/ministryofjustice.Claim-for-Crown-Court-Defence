class ExternalUsers::Admin::ProvidersController < ExternalUsers::Admin::ApplicationController
  include ProviderAdminConcern

  def regenerate_api_key
    @provider.regenerate_api_key!
    redirect_to external_users_admin_provider_path(@provider), notice: 'API key successfully updated'
  end

  def edit
    render 'shared/providers/edit'
  end

  def update
    if @provider.update(provider_params.except(*filtered_params))
      redirect_to external_users_admin_provider_path, notice: 'Provider successfully updated'
    else
      render 'shared/providers/edit'
    end
  end

  private

  def set_provider
    @provider = current_user.persona.provider
  end

  def filtered_params
    %i[roles provider_type]
  end
end
