# frozen_string_literal: true

module Effective
  module Datatables
    # class for Keycloak AccountUserDatatable, used as an alternate to UserAccountDatatable
    class AccountUserDatatable < Effective::Datatable
      include Config::SiteModelConcern
      include Rails.application.routes.url_helpers
      include ApplicationHelper
      include ActionView::Helpers::TextHelper
      include Config::AcaModelConcern

      datatable do
        table_column :name, :label => 'USERNAME', :filter => false, :sortable => true
        table_column :email, :label => 'USER EMAIL', :filter => false, :sortable => false
        table_column :ssn, :label => 'SSN', :filter => false, :sortable => false
        table_column :dob, :label => 'DOB', :filter => false, :sortable => false
        table_column :hbx_id, :label => 'HBX ID', :filter => false, :sortable => false
        table_column :status, :label => 'Status', :filter => false, :sortable => false
        table_column :role_type, :label => 'Role Type', :filter => false, :sortable => false
        table_column :permission, :label => 'Permission level', :filter => false, :sortable => false
        table_column :actions, :width => '50px', :proc => proc { |row|
          user = row.last[:user]
          account = row.last[:account]

          dropdown = [
            ['Reset Password', user_account_reset_password_path(user_id: user.id, account_id: account[:id], username: account[:username]), account_actions_access_enabled?(current_user, user) ? 'ajax' : 'disabled'],
            ['Unlock / Lock Account', user_account_lockable_path(user_id: user.id, account_id: account[:id], enabled: account[:enabled]), account_actions_access_enabled?(current_user, user) ? 'ajax' : 'disabled'],
            ['View Login History',login_history_user_path(id: user.id), account_actions_access_enabled?(current_user, user) ? 'ajax' : 'disabled'],
            ['Edit Account', user_account_change_username_and_email_path(user_id: user.id, account_id: account[:id], username: account[:username], email: account[:email]), account_actions_access_enabled?(current_user, user) ? 'ajax' : 'disabled']
          ]
          render partial: 'datatables/shared/dropdown', locals: {dropdowns: dropdown, row_actions_id: "user_action_#{user.id}"}, formats: :html
        }, :filter => false, :sortable => false
      end

      def collection
        return @accounts_collection if defined?(@accounts_collection) && @accounts_collection.present?

        results = if attributes[:roles]
                    Operations::Accounts::Find.new.call(scope_name: :by_realm_role, criterion: attributes[:roles]).success
                  else
                    Operations::Accounts::Find.new.call(scope_name: :all, page_number: page, page_size: per_page).success
                  end

        @accounts_collection = if results.present?
                                 render_table_rows(results)
                               else
                                 [['None given']]
                               end
      end

      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def render_table_rows(results)
        result_ids = results.map { |result| result[:id] }
        users = User.where(:account_id.in => result_ids)
        return [['None present']] if users.empty?
        results.reduce([]) do |memo, result|
          result_user = users.detect { |user| user.account_id == result[:id] }
          if result_user
            memo + [[
              result[:username],
              result[:email] || 'Unknown',
              truncate(number_to_obscured_ssn(result_user&.person&.ssn)) || 'Unknown',
              result_user&.person&.dob || 'Unknown',
              result_user&.person&.hbx_id || 'Unknown',
              result[:enabled] ? 'Unlocked' : 'Locked',
              (result_user&.roles || ['None']).join(', '),
              permission_type(result_user),
              {
                user: result_user,
                account: result
              }
            ]]
          else
            memo
          end
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      scopes do
        scope :legal_name, "Hello"
      end

      def permission_type(user)
        user&.person&.hbx_staff_role&.permission&.name || 'N/A'
      end

      def account_actions_access_enabled?(current_user, target_user)
        Permission.has_permission_to_modify?(current_user, target_user)
      end

      def total_records
        @total_records ||= count_total_records
      end

      def fetch_page_of_data
        if global_search_string.present?
          @total_records = count_total_records
          results = Operations::Accounts::Find.new.call(scope_name: :by_any, criterion: global_search_string.strip, page_number: page, page_size: per_page).success
          render_table_rows(results)
        else
          collection
        end
      end

      def array_tool_paginate(_col)
        fetch_page_of_data
      end

      def count_total_records
        if global_search_string.present?
          Operations::Accounts::Find.new.call(scope_name: :by_any, criterion: global_search_string.strip).success.length
        else
          Operations::Accounts::Find.new.call(scope_name: :count_all).success
        end
      end

      def global_search?
        true
      end

      def nested_filter_definition
        {
          roles: [
            #{scope: 'all', label: 'All'},
            {scope: 'hbx_staff', label: 'HBX Staff'},
            {scope: 'broker', label: 'Brokers'},
            {scope: 'consumer', label: 'Consumers'}
          ],
          top_scope: :roles
        }
      end
    end
  end
end