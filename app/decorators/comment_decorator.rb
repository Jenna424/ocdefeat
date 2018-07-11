class CommentDecorator < ApplicationDecorator
  include Draper::LazyHelpers
  delegate_all

  def label
    if current_user.therapist?
      "Give the patient some therapy pointers to defeat this obsession"
    elsif current_user.patient?
      "Voice your concerns to a counselor about this obsession"
    end
  end

  def placefill
    current_user.patient? ? "Feel free to vent here..." : "Add mental health tips..."
  end
end
