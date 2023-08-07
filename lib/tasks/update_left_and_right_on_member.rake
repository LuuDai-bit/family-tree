namespace :family_tree do
  desc "Update left and right on old member"
  task update_left_and_right_on_member: :environment do
    ActiveRecord::Base.transaction do
      upsert_members = []
      members = Member.where(parent_id: nil, count_left: nil, count_right: nil).find_each do |member|
        descendant = member.descendant.map do |family_member|
          family_member.assign_attributes(count_left: nil, count_right: nil, group_id: member.id)
          family_member
        end
        member.group_id = member.id
        family_line = build_family_line(member.attributes, descendant.map(&:attributes))
        family_line = numbering_members(family_line)
        upsert_members += family_line
      end

      Member.upsert_all(upsert_members) unless upsert_members.blank?
    end
  rescue StandardError => e
    puts e.message
  end

  def build_family_line(member, descendant)
    sorted_family_line = [member] + find_members(member, descendant) + [member]
  end

  def find_members(member, descendant)
    child = descendant.select { |family_member| family_member['parent_id'] == member['id'] }
    result_child = child.dup

    return [] if result_child.blank?

    index_count_up = 0
    child.each do |family_member|
      addition_members = find_members(family_member, descendant - child).flatten
      result_child.insert(1 + index_count_up, addition_members)
      result_child.flatten!
      result_child.insert(1 + index_count_up + addition_members.length, family_member)
      index_count_up += addition_members.length + 2
    end

    result_child
  end

  def numbering_members(family_line)
    count = 1

    family_line.each do |family_member|
      if family_member['count_left'].blank?
        family_member['count_left'] = count
      else
        family_member['count_right'] = count
      end
      count += 1
    end

    family_line
  end
end
