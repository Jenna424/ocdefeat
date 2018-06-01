module UsersHelper
  def obsession_pronouns
    if current_user.patient?
      "You are currently conquering"
    elsif current_user.therapist? || current_user.admin?
      "The patient is currently conquering"
    end
  end

  def plan_pronouns
    if current_user.patient?
      "You have designed"
    elsif current_user.therapist? || current_user.admin?
      "The patient has designed"
    end
  end

  def panicky_patients
    if User.patients_very_unnerved.empty?
      content_tag(:p, "Patients did not report debilitating degrees of distress. The anxiety generated by each OCD trigger does not exceed level 5.")
    else
      content_tag(:ul) do
        User.patients_very_unnerved.each do |user|
          concat(content_tag(:li, user.name))
        end
      end
    end
  end

  def vary_variant(user)
    case user.variant
    when "Traditional"
      "Traditional"
    when "Purely Obsessional"
      "Pure-O"
    when "Both"
      "Hybrid of Traditional and Pure-O"
    end
  end

  def sort_severity(severity)
    content_tag(:p) do
      content_tag(:strong, "#{severity}ly Obsessive Patients:")
    end +
    if User.by_ocd_severity(severity).empty?
      content_tag(:p) do
        content_tag(:em, "No patients were diagnosed with #{severity} OCD.")
      end
    else
      content_tag(:ul) do
        User.by_ocd_severity(severity).each do |user|
          concat(content_tag(:li, link_to(user.name, user_path(user))))
        end
      end
    end
  end

end
