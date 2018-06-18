class PlanPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin? # An admin views an index of all plan titles
        scope.all
      elsif user.therapist? # A therapist views an index of her own patients' plans
        scope.where(obsession_id: [user.counselees.map {|counselee| counselee.obsession_ids}.flatten])
      elsif user.patient? # A patient views an index of her own plans
        scope.where(obsession_id: user.obsession_ids)
      end
    end
  end

  def new? # Only patients can view the form to create an ERP plan
    user.patient?
  end

  def create? # Only patients can create an ERP plan overview (title, goal, obsession_id, flooded, progress)
    user.patient?
  end

  def show?
    user.therapist? || plan_owner
  end

  def edit? # Only therapists and patient who developed plan can view form to edit plan title and goal
    user.therapist? || plan_owner
  end

  def permitted_attributes # once the plan's :obsession_id was assigned in plans#create, it cannot be changed
    if user.therapist?
      [:title, :goal, :flooded]
    elsif plan_owner
      [:title, :goal, :flooded, :progress]
    end
  end

  def update? # Only therapists and patient who developed plan can edit preliminary plan title, goal, flooded
    user.therapist? || plan_owner
  end

  def destroy? # Only patient who created ERP plan or therapist can delete it
    user.therapist? || plan_owner
  end

  private

    def plan_owner
      user == record.user
    end
end
