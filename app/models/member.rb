class Member < ApplicationRecord
  extend RawSqlConcern

  DEFAULT_GIVE_BIRTH_AGE = 25

  def ancestor
    sql = <<-SQL
      with recursive cte (id, parent_id) as (
        select id, parent_id
        from members
        where id = #{self.id}
        union all
        select m.id, m.parent_id
        from members as m
        inner join cte
        on m.id = cte.parent_id
      )
      select id from cte
    SQL

    ancestor_ids = Member.execute_sql(sql).to_a.flatten
    Member.where(id: ancestor_ids)
  end

  def descendant
    sql = <<-SQL
      with recursive cte (id, parent_id) as (
        select id, parent_id
        from members
        where parent_id = #{self.id}
        union all
        select m.id, m.parent_id
        from members as m
        inner join cte
        on m.parent_id = cte.id
      )
      select id from cte
    SQL

    descendant_ids = Member.execute_sql(sql).to_a.flatten
    Member.where(id: descendant_ids)
  end

  class << self
    def seed_family_line(level=1)
      parent_id = nil
      first_ancestor_born_year = Time.current.year - (level * DEFAULT_GIVE_BIRTH_AGE)
      upsert_members = []

      ActiveRecord::Base.transaction do
        (0..level).each do |current_level|
          member_born_year = first_ancestor_born_year + (current_level * DEFAULT_GIVE_BIRTH_AGE)
          parent = Member.create!(name: Faker::Name.name, date_of_birth: Time.current.change(year: member_born_year), parent_id:)
          parent_id = parent.id
        end
      end
    end
  end
end
