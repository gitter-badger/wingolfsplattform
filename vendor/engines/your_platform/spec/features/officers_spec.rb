require 'spec_helper'
include SessionSteps

feature "Officers Management" do

  background do
    @group = create(:group)
    @user = create(:user)
    @president_group = @group.officers_parent.child_groups.create(name: "President")
    @president_group << @user
  end

  scenario "visiting a group site and looking at the officers" do
    login(:user)
    visit group_path(@group)

    within(".officers.section") do
      page.should have_text "President"
      page.should have_text @user.title
    end
  end

  describe "officers of subgroups: " do
    background do
      @subgroup = @group.child_groups.create
      @ceo_group = @subgroup.officers_parent.child_groups.create(name: "CEO")
      @ceo_group << @user
    end

    scenario "visiting the group page and looking at the officers" do
      login(:user)
      visit group_path(@group)

      within(".officers.section") do
        page.should have_text "President"
        page.should have_no_text "CEO"
      end
    end
  end
  
  scenario "assigning an officer", :js => true do
    login(:admin)
    visit group_path(@group)
    
    @new_user = create(:user)

    within("div.officers.section") do
      page.should have_text "President"
      page.should have_text @user.title
      
      click_on I18n.t(:edit)
      fill_in "direct_members_titles_string", with: @new_user.title
      find(".save_button").click
    end
    
    wait_for_ajax; wait_for_ajax
    @group.officers_parent.child_groups.where(name: "President").first.members.should include @new_user
    @group.officers_parent.child_groups.where(name: "President").first.members.should_not include @user
  end

end
