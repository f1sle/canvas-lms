# frozen_string_literal: true

#
# Copyright (C) 2012 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ProfileController do
  before :once do
    course_with_teacher(:active_all => true)
    user_with_pseudonym(:active_user => true)
  end

  describe "show" do
    it "should not require an id for yourself" do
      user_session(@user)

      get 'show'
      expect(response).to render_template('profile')
    end

    it "should chain to settings when it's the same user" do
      user_session(@user)

      get 'show', params: {:user_id => @user.id}
      expect(response).to render_template('profile')
    end

    it "should require a password session when chaining to settings" do
      user_session(@user)
      session[:used_remember_me_token] = true

      get 'show', params: {:user_id => @user.id}
      expect(response).to redirect_to(login_url)
    end

    describe "other user's profile" do
      before :each do
        # to allow viewing other user's profile
        allow(@controller).to receive(:api_request?).and_return(true)
      end

      it "should include common contexts in @user_data" do
        user_session(@teacher)

        # teacher and user have a group and course in common
        group = group()
        group.add_user(@teacher, 'accepted')
        group.add_user(@user, 'accepted')
        student_in_course(user: @user, active_all: true)

        get 'show', params: {user_id: @user.id}
        expect(assigns(:user_data)[:common_contexts].size).to eql(2)
        expect(assigns(:user_data)[:common_contexts][0]['id']).to eql(@course.id)
        expect(assigns(:user_data)[:common_contexts][0]['roles']).to eql(['Student'])
        expect(assigns(:user_data)[:common_contexts][1]['id']).to eql(group.id)
        expect(assigns(:user_data)[:common_contexts][1]['roles']).to eql(['Member'])
      end
    end
  end

  describe "update" do
    it "should allow changing the default e-mail address and nothing else" do
      user_session(@user, @pseudonym)
      cc = @cc
      expect(cc.position).to eq 1
      cc2 = communication_channel(@user, {username: 'email2@example.com', active_cc: true})
      expect(cc2.position).to eq 2
      put 'update', params: {:user_id => @user.id, :default_email_id => cc2.id}, format: 'json'
      expect(response).to be_successful
      expect(cc2.reload.position).to eq 1
      expect(cc.reload.position).to eq 2
    end

    it "should clear email cache" do
      enable_cache do
        @user.email # prime cache
        user_session(@user, @pseudonym)
        @cc2 = communication_channel(@user, {username: 'email2@example.com', active_cc: true})
        put 'update', params: {:user_id => @user.id, :default_email_id => @cc2.id}, format: 'json'
        expect(response).to be_successful
        expect(@user.email).to eq @cc2.path
      end
    end

    describe "personal pronouns" do
      before :once do
        @user.account.settings = { :can_add_pronouns => true }
        @user.account.save!
      end

      it "should allow changing pronouns" do
        user_session(@user, @pseudonym)
        expect(@user.pronouns).to eq nil
        put 'update', params: {:user => {:pronouns => "  He/Him "}}, format: 'json'
        expect(response).to be_successful
        @user.reload
        expect(@user.read_attribute(:pronouns)).to eq "he_him"
        expect(@user.pronouns).to eq "He/Him"
      end

      it "should allow unsetting pronouns" do
        user_session(@user, @pseudonym)
        @user.pronouns = " Dude/Guy  "
        @user.save!
        expect(@user.pronouns).to eq "Dude/Guy"
        put 'update', params: {:user => {:pronouns => ''}}, format: 'json'
        expect(response).to be_successful
        @user.reload
        expect(@user.pronouns).to eq nil
      end

      it "should not allow setting pronouns not on the approved list" do
        user_session(@user, @pseudonym)
        expect(@user.pronouns).to eq nil
        put 'update', params: {:user => {:pronouns => "Pro/Noun"}}, format: 'json'
        expect(response).to be_successful
        @user.reload
        expect(@user.pronouns).to eq nil
      end

      it 'should not allow setting pronouns if the setting is disabled' do
        @user.account.settings[:can_change_pronouns] = false
        @user.account.save!
        user_session(@user, @pseudonym)
        put 'update', params: {:user => {:pronouns => "Pro/Noun"}}, format: 'json'
        expect(response).to be_successful
        @user.reload
        expect(@user.pronouns).to eq nil
      end
    end

    it "should allow changing the default e-mail address and nothing else (name changing disabled)" do
      @account = Account.default
      @account.settings = { :users_can_edit_name => false }
      @account.save!
      user_session(@user, @pseudonym)
      cc = @cc
      expect(cc.position).to eq 1
      cc2 = communication_channel(@user, {username: 'email2@example.com', active_cc: true})
      expect(cc2.position).to eq 2
      put 'update', params: {:user_id => @user.id, :default_email_id => cc2.id}, format: 'json'
      expect(response).to be_successful
      expect(cc2.reload.position).to eq 1
      expect(cc.reload.position).to eq 2
    end

    it "should not let an unconfirmed e-mail address be set as default" do
      user_session(@user, @pseudonym)
      cc = @cc
      cc2 = communication_channel(@user, {username: 'email2@example.com', cc_state: 'unconfirmed'})
      put 'update', params: {:user_id => @user.id, :default_email_id => cc2.id}, format: 'json'
      expect(@user.email).to eq cc.path
    end

    it "should not allow a student view student profile to be edited" do
      user_session(@teacher)
      @fake_student = @course.student_view_student
      session[:become_user_id] = @fake_student.id

      put 'update', params: {:user_id => @fake_student.id}
      assert_unauthorized
    end
  end

  describe "GET 'communication'" do
    it "should not fail when a user has a notification policy with no notification" do
      # A user might have a NotificationPolicy with no Notification if the policy was created
      # as part of throttling a user's "immediate" messages. Eventually we should fix how that
      # works, but for now we just make sure that that state does not cause an error for the
      # user when they go to their notification preferences.
      user_session(@user)
      cc = communication_channel(@user, {username: 'user@example.com', active_cc: true})
      cc.notification_policies.create!(:notification => nil, :frequency => 'daily')

      get 'communication'
      expect(response).to be_successful
    end
  end

  describe "update_profile" do
    before :once do
      user_with_pseudonym
      @user.register
    end

    before :each do
      # reload to catch the user change
      user_session(@user, @pseudonym.reload)
    end

    it "should let you change your short_name and profile information" do
      put 'update_profile',
          params: {:user => {:short_name => 'Monsturd', :name => 'Jenkins'},
          :user_profile => {:bio => '...', :title => '!!!'}},
          format: 'json'
      expect(response).to be_successful

      @user.reload
      expect(@user.short_name).to eql 'Monsturd'
      expect(@user.name).not_to eql 'Jenkins'
      expect(@user.profile.bio).to eql '...'
      expect(@user.profile.title).to eql '!!!'
    end

    it "should not let you change your short_name information if you are not allowed" do
      account = Account.default
      account.settings = { :users_can_edit_name => false }
      account.save!

      old_name = @user.short_name
      old_title = @user.profile.title
      put 'update_profile',
          params: {:user => {:short_name => 'Monsturd', :name => 'Jenkins'},
          :user_profile => {:bio => '...', :title => '!!!'}},
          format: 'json'
      expect(response).to be_successful

      @user.reload
      expect(@user.short_name).to eql old_name
      expect(@user.name).not_to eql 'Jenkins'
      expect(@user.profile.bio).to eql '...'
      expect(@user.profile.title).to eql old_title
    end

    it "should let you set visibility on user_services" do
      @user.user_services.create! :service => 'skype', :service_user_name => 'user', :service_user_id => 'user', :visible => true
      @user.user_services.create! :service => 'twitter', :service_user_name => 'user', :service_user_id => 'user', :visible => false

      put 'update_profile',
        params: {:user_profile => {:bio => '...'},
        :user_services => {:twitter => "1", :skype => "false"}},
        format: 'json'
      expect(response).to be_successful

      @user.reload
      expect(@user.user_services.where(service: 'skype').first.visible?).to be_falsey
      expect(@user.user_services.where(service: 'twitter').first.visible?).to be_truthy
    end

    it "should let you set your profile links" do
      put 'update_profile',
        params: {:user_profile => {:bio => '...'},
        :link_urls => ['example.com', 'foo.com', '', '///////invalid'],
        :link_titles => ['Example.com', 'Foo', '', 'invalid']},
        format: 'json'
      expect(response).to be_successful

      @user.reload
      expect(@user.profile.links.map { |l| [l.url, l.title] }).to eq [
        %w(http://example.com Example.com),
        %w(http://foo.com Foo)
      ]
    end

    it "should let you remove set pronouns" do
      @user.update(pronouns: 'he_him')
      expect {
        put 'update_profile', params: {:pronouns => nil}, format: 'json'
      }.to change {
        @user.reload.pronouns
      }.from('He/Him').to(nil)
      expect(response).to be_successful
    end
  end

  describe "content_shares" do
    before :once do
      teacher_in_course(:active_all => true)
      student_in_course(:active_all => true)
    end

    describe "direct_share flag is enabled" do
      before :once do
        @teacher.account.enable_feature!(:direct_share)
      end

      it "should show if user has any non-student enrollments" do
        allow(Canvas::DynamicSettings).to receive(:find).and_return({'base_url' => 'the_ccv_url'})
        user_session(@teacher)
        get 'content_shares', params: {user_id: @teacher.id}
        expect(response).to render_template('content_shares')
        expect(assigns.dig(:js_env, :COMMON_CARTRIDGE_VIEWER_URL)).to eq('the_ccv_url')
      end

      it "should show if the user has an account membership" do
        user_session(account_admin_user)
        get 'content_shares', params: {user_id: @admin.id}
        expect(response).to render_template('content_shares')
      end

      it "should 404 if user has only student enrollments" do
        skip("LS-1997 failing on not found exception that it should be looking for")
        user_session(@student)
        get 'content_shares', params: {user_id: @student.id}
        expect(response).to be_not_found
      end
    end

    describe "direct_share flag is disabled" do
      before :once do
        @user.account.disable_feature!(:direct_share)
      end

      it "should 404 even if user has non-student enrollments" do
        skip("LS-1997 failing on not found exception that it should be looking for")
        teacher_in_course(:active_all => true)
        user_session(@teacher)
        get 'content_shares', params: {user_id: @teacher.id}
        expect(response).to be_not_found
      end
    end
  end

  describe "GET #qr_mobile_login" do
    context "mobile_qr_login setting is enabled" do
      before :once do
        Account.default.settings[:mobile_qr_login_is_enabled] = true
        Account.default.save
      end

      it "should render empty html layout" do
        user_session(@user)
        get "qr_mobile_login"
        expect(response).to render_template "layouts/application"
        expect(response.body).to eq ""
      end

      it "should redirect to login if no active session" do
        get "qr_mobile_login"
        expect(response).to redirect_to "/login"
      end

      it "should 404 if IMP is missing" do
        allow_any_instance_of(ProfileController).to receive(:instructure_misc_plugin_available?).and_return(false)
        user_session(@user)
        get "qr_mobile_login"
        expect(response).to be_not_found
      end
    end

    context "mobile_qr_login setting is disabled" do
      before :once do
        Account.default.settings[:mobile_qr_login_is_enabled] = false
        Account.default.save
      end

      it "should 404" do
        user_session(@user)
        get "qr_mobile_login"
        expect(response).to be_not_found
      end
    end
  end
end
