#
# Copyright (C) 2011 Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../api_spec_helper')

describe "Admins API", :type => :integration do
  before do
    @admin = account_admin_user
    user_with_pseudonym(:user => @admin)
  end

  describe "create" do
    before :each do
      @new_user = user(:name => 'new guy')
      @user = @admin
    end

    it "should flag the user as an admin for the account" do
      json = api_call(:post, "/api/v1/accounts/#{@admin.account.id}/admins",
        { :controller => 'admins', :action => 'create', :format => 'json', :account_id => @admin.account.id.to_s },
        { :user_id => @new_user.id })
      @new_user.reload
      @new_user.account_users.size.should == 1
      admin = @new_user.account_users.first
      admin.account.should == @admin.account
    end

    it "should default the membership type of the admin association to AccountAdmin" do
      json = api_call(:post, "/api/v1/accounts/#{@admin.account.id}/admins",
        { :controller => 'admins', :action => 'create', :format => 'json', :account_id => @admin.account.id.to_s },
        { :user_id => @new_user.id })
      @new_user.reload
      admin = @new_user.account_users.first
      admin.membership_type.should == 'AccountAdmin'
    end

    it "should respect the provided membership type, if any" do
      json = api_call(:post, "/api/v1/accounts/#{@admin.account.id}/admins",
        { :controller => 'admins', :action => 'create', :format => 'json', :account_id => @admin.account.id.to_s },
        { :user_id => @new_user.id, :membership_type => "CustomAccountUser" })
      @new_user.reload
      admin = @new_user.account_users.first
      admin.membership_type.should == 'CustomAccountUser'
    end

    it "should return json of the new admin association" do
      json = api_call(:post, "/api/v1/accounts/#{@admin.account.id}/admins",
        { :controller => 'admins', :action => 'create', :format => 'json', :account_id => @admin.account.id.to_s },
        { :user_id => @new_user.id })
      @new_user.reload
      admin = @new_user.account_users.first
      json.should == {
        "id" => admin.id,
        "membership_type" => admin.membership_type,
        "user" => {
          "id" => @new_user.id,
          "name" => @new_user.name,
          "short_name" => @new_user.short_name,
          "sortable_name" => @new_user.sortable_name
        }
      }
    end
  end
end

