class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  def index # implicitly renders app/views/users/index.html.erb (where #filter method will be called to determine what the users index looks like depending on the viewer's role and the filtered objects they're permitted to see)
    users = policy_scope(User) # we're filtering users - users stores the array of user instances available to the type of viewer
    # when an admin views the users index, @users stores 'array' of ALL user instances (for the table)
    # when a therapist views the users index, @users stores 'array' of only patients
    # when a patient views the users index, @users stores 'array' of only therapists (like directory w/ contact info)

    # From an admin's perspective, the users index page presents a table to manage all users accounts, i.e.,
    # change users' roles, delete accounts. There is also 1 filter to filter users by current role
    # The first 4 instance variables below correspond to locals used in app/views/filter_users/_admin.html.erb partial (which is rendered on users index pg when admin is viewer)
    if current_user.admin?
      @table_users = users # @table_users stores array of all user instances
      @filtered_users = users
      @prospective_patients = users.awaiting_assignment(%w(Therapist Admin), 1)
      @therapists_to_be = users.awaiting_assignment(%w(Patient Admin), 2)
      @aspiring_admins = users.awaiting_assignment(%w(Patient Therapist), 3)

      if !params[:role].blank? # Admin filters users by role ("patient", "therapist" or "admin")
        if users.by_role(params[:role]).empty? # If there are no users with the selected role
          flash.now[:alert] = "No #{params[:role]}s were found."
        else
          @filtered_users = users.by_role(params[:role]) # stores 'array' of all users with the selected role
          flash.now[:notice] = "You found #{@filtered_users.count} #{params[:role].pluralize(@filtered_users.count)}!"
        end
      else
        @filtered_users = users # Admin did not choose a filter, so @filtered_users stores all users
      end
    elsif current_user.therapist? # When therapist views users index page, users variable stores all patients
      if !params[:severity].blank? # Therapist filters patients by OCD severity
        if users.by_ocd_severity(params[:severity]).empty? # If no patients have the selected OCD severity
          flash.now[:alert] = "No patients were diagnosed with #{params[:severity]} OCD."
        else
          @filtered_users = users.by_ocd_severity(params[:severity]) # stores 'array' of all patients with the selected OCD severity
          flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} #{'has'.pluralize(@filtered_users.count)} #{params[:severity]} OCD!"
        end
      elsif !params[:variant].blank? # Therapist filters patients by OCD variant
        if users.by_variant(params[:variant]).empty? # If no patients have the specified OCD variant
          flash.now[:alert] = "No patients with that variant of OCD were found."
        else
          @filtered_users = users.by_variant(params[:variant]) # stores 'array' of all patients with a specific OCD variant
          if params[:variant] == "Both"
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} #{'is'.pluralize(@filtered_users.count)} both traditionally and purely obsessive."
          elsif params[:variant] == "Purely Obsessional"
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} #{'is'.pluralize(@filtered_users.count)} purely obsessive."
          else
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} #{'is'.pluralize(@filtered_users.count)} traditionally obsessive."
          end
        end
      elsif !params[:severity_and_variant].blank? # Therapist filters by specific OCD severity ("Mild", "Moderate", "Severe", "Extreme") and variant of OCD ("Traditional", "Purely Obsessional", "Both")
        severity = params[:severity_and_variant].split(" and ").first
        variant = params[:severity_and_variant].split(" and ").last
        if users.by_severity_and_variant(severity, variant).empty?
          flash.now[:alert] = "There are no patients with #{severity.downcase} OCD and #{variant.downcase} types of compulsions."
        else
          @filtered_users = users.by_severity_and_variant(severity, variant)
          flash.now[:notice] = "You found #{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} with #{severity.downcase} OCD and #{variant.downcase} types of compulsions!"
        end
      elsif !params[:desensitization_deficiency].blank? # Therapist filters by patients who have at least 1 obsession for which no ERP plans were designed, or by patients with preliminary plans (sans steps)
        if params[:desensitization_deficiency] == "Patients with obsession lacking ERP plans"
          if users.with_obsession_without_plan.empty?
            flash.now[:alert] = "Patients either have no obsessions or are becoming desensitized to all obsessions."
          else
            @filtered_users = users.with_obsession_without_plan
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} created at least one obsession that lacks ERP plans."
          end
        elsif params[:desensitization_deficiency] == "Patients with preliminary plans"
          if users.patients_planning_preliminarily.empty?
            flash.now[:alert] = "No patients designed preliminary ERP plans, i.e., plans sans steps."
          else
            @filtered_users = users.patients_planning_preliminarily # stores AR::Relation of patients who have preliminary ERP plans
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} designed at least one preliminary ERP plan."
          end
        end
      elsif !params[:symptoms_presence].blank? # Therapist filters patients by symptomatic/asymptomatic patients
        if users.all? {|user| user.obsessions.empty?} # If none of the patients have obsessions
          flash.now[:notice] = "All patients are asymptomatic since nobody is obsessing!"
        elsif params[:symptoms_presence] == "Symptomatic patients"
          if users.symptomatic.empty?
            flash.now[:alert] = "No patients present with physical symptoms of OCD distress."
          else
            @filtered_users = users.symptomatic
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} #{'is'.pluralize(@filtered_users.count)} physically symptomatic of OCD distress."
          end
        elsif params[:symptoms_presence] == "Asymptomatic patients"
          if users.asymptomatic.empty?
            flash.now[:alert] = "All patients with obsessions present with physical symptoms of OCD distress."
          else
            @filtered_users = users.asymptomatic
            flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} #{'is'.pluralize(@filtered_users.count)} asymptomatic."
          end
        end
      elsif !params[:ruminating_recently].blank? # Therapist filters patients by those who created new obsessions yesterday
        if users.recent_ruminators.empty?
          flash.now[:alert] = "No patients reported new obsessions yesterday."
        else
          @filtered_users = users.recent_ruminators
          flash.now[:notice] = "#{@filtered_users.count} #{'patient'.pluralize(@filtered_users.count)} reported new obsessions yesterday!"
        end
      elsif !params[:num_obsessions].blank? # Therapist filters patients by obsession count
        if users.all? {|user| user.obsessions.empty?} # If no patient has obsessions
          flash.now[:alert] = "The OCD volume is low. Not a single patient has obsessions!"
        else # Patients have obsessions
          first_obsession_count = users.first.obsession_count
          if users.count == 1 # If there is only 1 patient
            @filtered_users = users # AR::Relation 'array' of 1 user instance
            flash.now[:notice] = "A single patient was found who has #{first_obsession_count} #{'obsession'.pluralize(first_obsession_count)}!"
          elsif users.all? {|user| user.obsession_count == first_obsession_count} # > 1 patient, but all patients have the same number of obsessions
            flash.now[:alert] = "Patients cannot be ordered by obsession count, as all patients have #{first_obsession_count} #{'obsession'.pluralize(first_obsession_count)}!"
          elsif params[:num_obsessions] == "Least to Most Obsessions"
            @filtered_users = users.least_to_most_obsessions # stores array of patients ordered by those w/ least to most obsessions
            flash.now[:notice] = "Patients are ordered by ascending obsession count!"
          else
            @filtered_users = users.most_to_least_obsessions # stores array of patients ordered by those w/ most to least obsessions
            flash.now[:notice] = "Patients are ordered by descending obsession count!"
          end
        end
      else
        @filtered_users = users # @filtered_users stores array of all patients if no filter was applied when therapist views page
      end
    elsif current_user.patient?
      @therapists = users # @therapists stores array of all therapists when patient views users index page
    end
  end

  def new # implicitly renders app/views/users/new.html.erb view file
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id # log in the user
      redirect_to user_path(@user), notice: "You successfully registered and created your preliminary profile, #{current_user.name}!"
    else
      flash.now[:error] = "Your registration attempt was unsuccessful. Please try again."
      render :new # present the registration form so the user can try signing up again
    end
  end

  def show
    render show_template # private method #show_template returns string name of view file to be rendered
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to user_path(@user), notice: "User information was successfully updated!"
    else
      flash.now[:error] = "Your attempt to edit user information was unsuccessful. Please try again."
      render :edit
    end
  end

  def destroy
    @user.destroy
    if current_user.unassigned_user?
      redirect_to root_path, notice: "Your preliminary profile was successfully deleted."
    elsif current_user.patient?
      redirect_to root_path, notice: "We hope that your experience with OCDefeat was productive and meaningful, and that you have acquired the skillset necessary to defeat OCD!"
    elsif current_user.therapist?
      redirect_to root_path, notice: "We hope that your experience working as an OCDefeat Therapy Forum Facilitator was rewarding. Thank you for helping our patients defeat OCD!"
    elsif current_user.admin?
      redirect_to users_path, notice: "The user's account was successfully deleted."
    end
  end

  private

    def set_user
      @user = User.find(params[:id])
    end

    def show_template # this method returns the string name of the show template to render, which depends on the user's role
      set_user # calling private method defined above
      case set_user.role
      when set_user.unassigned_user?
        "unassigned_user"
      when set_user.patient?
        "patient"
      when set_user.therapist?
        "therapist"
      when set_user.admin?
        "admin"
      end
      "#{set_user.role}_#{action_name}"
    end

    def user_params
      params.require(:user).permit(
        :name,
        :email,
        :password,
        :password_confirmation,
        :uid,
        :role_requested,
        :variant,
        :severity,
        :role
      )
    end
end
