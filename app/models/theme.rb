class Theme < ApplicationRecord
  has_many :obsession_themes
  has_many :obsessions, through: :obsession_themes
end
