class User < ApplicationRecord
  enum role: { unassigned_user: 0, patient: 1, therapist: 2, admin: 3 }
  #enum role: { "unassigned_user" => 0, "patient" => 1, "therapist" => 2, "admin" => 3 }
  has_many :obsessions, dependent: :destroy
  has_many :plans, through: :obsessions, dependent: :destroy

  validates :name, presence: true
  validates :email, email: true, uniqueness: true, allow_blank: true
  # I only want to validate the email attribute of a user instance if it's present
  has_secure_password
  validates :password, presence: true, length: { minimum: 8 }, allow_nil: true
  # when a user edits their user information, they don't have to retype their password
  def self.find_or_create_by_omniauth(auth_hash)
    self.where(provider: auth_hash["provider"], uid: auth_hash["uid"]).first_or_create do |user|
      user.name = auth_hash["info"]["name"] # "Jenna Leopold"
      user.twitter_handle = auth_hash["info"]["nickname"] # "code_snippet_JL"
      user.bio = auth_hash["info"]["description"] # "build code, break code, ad infinitum"
      user.password = SecureRandom.hex # a random, unique string
      user.role_requested = "Patient"
      user.severity = "Mild"
      # we can't add a default role_requested value of "Patient" in users table because
      # our admin and therapists don't want to be patients (see seed data)
      # If a brand new user signs on via Twitter (user cannot be found in the DB),
      # by default, just set their role_requested to "Patient" and their OCD severity to "Mild"
      # as these can be edited, and the majority of app users will presumably be patients
    end
  end

  def self.patients
    self.where(role: 1)
  end

  def self.by_role(role_number)
    self.where(role: role_number)
  end

  def self.awaiting_assignment(rejected_roles, role_number)
    self.where.not(role_requested: rejected_roles, role: role_number)
  end
  # rejected_roles is an array of string roles the user does NOT want to be and
  # role_number is the requested role's integer value
  # so if we're looking for all unassigned_users who want to be patients, we call
  # User.awaiting_assignment(["Therapist", "Admin"], 1)
  # we're looking for user instances who are NOT already patients (with role = 1)
  # AND who did NOT request the roles of therapist or admin
  # Rails documentation favors .where.not instead of !=, but above method is same as saying:
  #def self.awaiting_assignment(role_requested, role_number)
   #self.where("role_requested = ? AND role != ?", role_requested, role_number)
  #end
end

# Explanation of #find_or_create_by_omniauth(auth_hash):
# Trying to find user instance by their provider attribute ("Twitter") and their user ID (uid) on Twitter
# If such a user exists in the DB already, return that user instance
# If a user instance does NOT exist with that UID from Twitter, then create one:
# The newly instantiated user instance that was just created is passed to the block,
# and we set its name attribute value = the name provided by Twitter -- auth_hash["info"]["name"],
# we set its twitter_handle = auth_hash["info"]["nickname"],
# we set its bio attribute = auth_hash["info"]["description"]
# and we give it a random, unique string password using SecureRandom.hex
# The user instance is returned at end of method call
