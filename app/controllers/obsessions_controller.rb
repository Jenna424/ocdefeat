class ObsessionsController < ApplicationController
  before_action :set_obsession, only: [:show, :edit, :update, :destroy]

  def new
    @obsession = Obsession.new # @obsession instance for form_for to wrap around
    authorize @obsession
    @themes = Theme.all # @themes stores all OCD themes so user can select which existing theme their new obsession pertains to
  end

  def create
    @obsession = current_user.obsessions.build(obsession_params)
    authorize @obsession

    if @obsession.save
      redirect_to obsession_path(@obsession), notice: "Your obsession was successfully created!"
    else
      flash.now[:error] = "Your attempt to create an obsession was unsuccessful. Please try again."
      render :new
    end
  end

  def show
    authorize @obsession
  end

  def edit
    authorize @obsession
    @themes = Theme.all
  end

  def update
    authorize @obsession

    if @obsession.update(obsession_params)
      redirect_to obsession_path(@obsession), notice: "Your obsession was successfully updated!"
    else
      flash.now[:error] = "Your attempt to edit your obsession was unsuccessful. Please try again."
      render :edit
    end
  end

  def destroy
    authorize @obsession
    @obsession.destroy
    redirect_to user_path(current_user), notice: "Congratulations on defeating your obsession!"
  end

  private

    def set_obsession
      @obsession = Obsession.find(params[:id])
    end

    def count_obsessions # this method is called before #index action
      obsessions = policy_scope(Obsession)
      if current_user.admin? && obsessions.empty?
        redirect_to user_path(current_user), alert: "The obsessions log is currently empty!"
      elsif current_user.therapist? && obsessions.empty?
        redirect_to user_path(current_user), alert: "None of your patients are currently obsessing, and all past obsessions have been defeated and deleted!"
      elsif current_user.patient? && current_user.obsessions.empty?
        redirect_to user_path(current_user), alert: "You're making progress! Looks like you haven't been obsessing lately! No obsessions were found."
      end
    end

    def obsession_params
      params.require(:obsession).permit(
        :intrusive_thought,
        :triggers,
        :time_consumed,
        :anxiety_rating,
        :symptoms,
        :rituals,
        :theme_ids => [],
        :themes_attributes => [:name]
      )
    end
end
