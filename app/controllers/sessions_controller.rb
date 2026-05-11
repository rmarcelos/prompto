class SessionsController < ApplicationController

    def new
        if logged_in?
            redirect_to user_path(current_user)
        end
    end

    def create
        user = User.find_by(email: params[:session][:email].downcase)
        if user && user.authenticate(params[:session][:password])
            session[:user_id] = user.id
            flash[:success] = t('sessions.flashes.create.success')
            redirect_to user
        else
            flash.now[:error] = t('sessions.flashes.create.invalid_credentials')
            render 'new'
        end
    end

    def destroy
        session[:user_id] = nil
        flash[:info] = t('sessions.flashes.destroy.success')
        redirect_to root_path
    end

end
