# frozen_string_literal: true

module ToMods
  # Helper class - generates altRepGroup and nameTitleGroup ids.
  class IdGenerator
    def initialize
      @alt_rep_group = 0
      @name_title_group = 0
    end

    def next_altrepgroup
      @alt_rep_group += 1
    end

    def next_nametitlegroup
      @name_title_group += 1
    end
  end
end
