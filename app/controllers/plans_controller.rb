class PlansController < ApplicationController
  before_action :prepare_plan, only: [:show, :edit, :update, :destroy]
  before_action :require_plans, only: [:index]
  before_action :preserve_plan, only: [:edit, :update]
  include AdminFiltersConcern

  def index
    plans = policy_scope(Plan)
    @counselees = policy_scope(User) if current_user.therapist? # used in app/views/filter_plans/_therapist.html.erb to store AR::Relation of the patients (counselees) that the therapist was assigned
    @themes = policy_scope(Theme) unless current_user.admin? # Theme.all - patients, therapists and admins can view all themes
    @obsessions = policy_scope(Obsession) # the patient's own obsessions / the therapist's patients' obsessions
    @plans = PlanFinder.new(plans).call(filter_plans_params) unless current_user.admin?
    if current_user.admin?
      @plans = filter_by_date
      #@done = plans.accomplished if !plans.accomplished.empty?
      #@undone = plans.unaccomplished if !plans.unaccomplished.empty?
    #elsif current_user.therapist?
      #if !params[:designer].blank? # Therapist filters plans by patient designer -- params[:designer] is the ID of the user whose plans we want to find
        #if plans.designed_by(params[:designer]).empty? # If the selected user did not design any plans
          #flash.now[:alert] = "No ERP plans were designed by patient #{@counselees.find(params[:designer]).name}."
        #else
          #@plans = plans.designed_by(params[:designer])
          #flash.now[:notice] = "You found #{plural_inflection(@plans)} designed by patient #{@plans.first.user.name}!"
        #end
      #elsif !params[:patient_progressing].blank? # Therapist filters plans by patient's progress toward plan completion -- params[:patient_progressing] is the ID of the user
        #patient_progressing = @counselees.find(params[:patient_progressing])
        #if patient_progressing.obsessions.empty? # If the selected patient has no obsessions
          #flash.now[:alert] = "No ERP plans were found for patient #{patient_progressing.name}, but that's okay because this patient is not obsessing!"
        #elsif patient_progressing.plans.empty? # If the selected patient has obsessions but no ERP plans
          #flash.now[:alert] = "Patient #{patient_progressing.name} should design ERP plans to overcome obsessions."
        #else # If the patient has plans
          #@done = patient_progressing.plans.accomplished if !patient_progressing.plans.accomplished.empty?
          #@undone = patient_progressing.plans.unaccomplished if !patient_progressing.plans.unaccomplished.empty?
          #flash.now[:notice] = "You retrieved #{patient_progressing.name}'s progress report, which identifies ERP plans that this patient finished and/or left unfinished!"
        #end
      #else # Therapist did not choose a filter for filtering plans
        #@plans = plans # stores all plans designed by the therapist's patients
        #flash.now[:notice] = "Collectively, your patients designed #{plural_inflection(@plans)} to gain exposure to their obsessions."
      #end # closes logic about filter selected
    end # closes logic about filterer's role
  end # closes #index action

  def new # Route helper #new_obsession_plan_path(obsession) returns GET "/obsessions/:obsession_id/plans/new"
    @obsession = Obsession.find(params[:obsession_id]) # @obsession is the parent. The form to create a new plan for an obsession is found at: "/obsessions/:obsession_id/plans/new"
    @plan = Plan.new # instance for form_for to wrap around
    authorize @plan
  end

  def create # When the form to create a new plan is submitted, form data is sent via POST request to "/obsessions/:obsession_id/plans"
    @obsession = Obsession.find(params[:obsession_id])
    @plan = @obsession.plans.build(plan_params)
    authorize @plan

    if @plan.save
      redirect_to plan_path(@plan), flash: { success: "You successfully created the ERP plan entitled \"#{@plan.title}.\"" }
    else
      flash.now[:error] = "Your attempt to create a new ERP plan was unsuccessful. Please try again."
      render :new
    end
  end

  def show
    authorize @plan
    @step = Step.new # instance for form_for to wrap around in nested resource form to create a new step on plan show page
    @plan_steps = @plan.steps # stores AR::Relation of all steps belonging to @plan
  end

  def edit
    authorize @plan
  end

  def update # PATCH or PUT request to "/plans/:id" maps to plans#update
    authorize @plan

    if @plan.update_attributes(permitted_attributes(@plan))
      if @plan.finished? # If the plan is updated from unfinished (progress = 0) to finished (progress = 1)
        redirect_to plan_path(@plan), flash: { success: "Congratulations on developing anxiety tolerance by finishing this ERP plan!" }
      else
        redirect_to plan_path(@plan), flash: { success: "An overview of this ERP plan was successfully updated!" }
      end
    else
      flash.now[:error] = "Your attempt to edit this ERP plan was unsuccessful. Please try again."
      render :edit
    end
  end

  def destroy  # DELETE request to "/plans/:id" maps to plans#destroy
    authorize @plan
    @plan.destroy
    redirect_to plans_path, flash: { success: "You successfully deleted an ERP plan!" }
  end

  private
    def preserve_plan
      plan = Plan.find(params[:id])
      if plan.finished?
        redirect_to plan_path(plan), alert: "You already accomplished and archived this ERP plan!"
      end
    end

    def prepare_plan
      @plan = Plan.find(params[:id])
    end

    def require_plans # called before plans#index
      if current_user.patient? && current_user.plans.empty? && !current_user.obsessions.empty? # The patient has no plans AND the patient has obsessions for which no plans were designed
        first_planless_obsession = current_user.obsessions.first
        redirect_to new_obsession_plan_path(first_planless_obsession), alert: "Looks like you're obsessing and need to gain some exposure. Why not design an ERP plan for this obsession now?"
      elsif current_user.therapist? && current_user.counselees.empty?
        redirect_to user_path(current_user), alert: "There are no ERP plans for you to review since you currently have no patients!"
      elsif policy_scope(Plan).empty? # If there are no plans to view (the therapist has patients, the patient doesn't have obsessions)
        msg = if current_user.admin?
          "The Index of ERP plans is currently empty."
        elsif current_user.therapist?
          "ERP plans designed by your patients were not found."
        elsif current_user.patient? # If the user has no plans but also has no obsessions
          "Looks like you're not implementing any ERP plans, but that's okay since you're not obsessing!"
        end
        redirect_to root_url, alert: "#{msg}"
      end
    end

    def plan_params
      params.require(:plan).permit(:title, :goal, :flooded, :obsession_id, :finished)
    end

    def filter_plans_params
      params.permit(:title_terms, :obsession_targeted, :accomplishment, :delineation, :approach, :ocd_theme, :designer)
    end
end
