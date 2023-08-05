class Member < ApplicationRecord
  extend RawSqlConcern

  DEFAULT_GIVE_BIRTH_AGE = 25
  NESTED_SET_ATTRIBUTE = %i[group_id count_left count_right]

  after_save :update_member_nested_set_attribute, if: :nested_attribute_blank?
  before_destroy :handle_destroy_family_line

  scope :by_group_id, -> (group_id){ where(group_id:) }
  scope :order_by_left, -> { order(:count_left) }

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

  def ancestor_nested_set
    return unless nested_set?

    Member.by_group_id(group_id)
          .where("count_left < #{count_left} AND count_right > #{count_right}")
          .order_by_left
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

  def descendant_nested_set
    return unless nested_set?

    Member.by_group_id(group_id)
          .where("count_left > #{count_left} AND count_right < #{count_right}")
          .order_by_left
  end

  class << self
    def seed_family_line(level=1)
      parent_id = nil
      first_ancestor_born_year = Time.current.year - (level * DEFAULT_GIVE_BIRTH_AGE)
      upsert_members = []

      ActiveRecord::Base.transaction do
        (1..level).each do |current_level|
          member_born_year = first_ancestor_born_year + (current_level * DEFAULT_GIVE_BIRTH_AGE)
          parent = Member.create!(name: Faker::Name.name, date_of_birth: Time.current.change(year: member_born_year), parent_id:)
          parent_id = parent.id
        end
      end
    end
  end

  private

  def nested_set?
    NESTED_SET_ATTRIBUTE.all? { |attribute| self.try(attribute).present? }
  end

  def update_left_and_right
    parent_member = Member.find(parent_id)
    need_shift_members = Member.by_group_id(parent_member.group_id)
                               .where("count_right >= #{parent_member.count_right} OR count_left >= #{parent_member.count_right}")
    upsert_member_attributes = need_shift_members.map do |member|
                                 member.count_left += 2 if member.count_left >= parent_member.count_right
                                 member.count_right += 2 if member.count_right >= parent_member.count_right
                                 member.attributes
                               end

    Member.upsert_all(upsert_member_attributes) if upsert_member_attributes.present?
  end

  def update_member_nested_set_attribute
    if parent_id.blank?
      self.update!(count_left: 1, count_right: 2, group_id: id)
    else
      parent_member = Member.find(parent_id)
      count_right = parent_member.count_right
      update_left_and_right
      self.update!(count_left: count_right, count_right: count_right + 1, group_id: parent_member.group_id)
    end
  end

  def handle_very_first_ancestor(member)
    member.assign_attributes
  end

  def handle_destroy_family_line
    width = count_right - count_left + 1
    need_shift_members = Member.by_group_id(group_id)
                               .where("count_right > #{count_right} OR count_left > #{count_right}")

    upsert_member_attributes = need_shift_members.map do |member|
                                 member.count_left -= width if member.count_left > count_right
                                 member.count_right -= width if member.count_right > count_right
                                 member.attributes
                               end

    Member.upsert_all(upsert_member_attributes) if upsert_member_attributes.present?

    self.descendant_nested_set.delete_all
  end

  def nested_attribute_blank?
    count_left.blank? && count_right.blank?
  end

  def new_record?
    count_left.blank? && count_right.blank?
  end
end
