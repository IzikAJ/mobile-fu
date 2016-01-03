require 'mobile-fu/tablet'
require 'rails'
require 'rack/mobile-detect'

module MobileFu
  autoload :Helper, 'mobile-fu/helper'

  class Railtie < Rails::Railtie
    initializer "mobile-fu.configure" do |app|
      app.config.middleware.use Rack::MobileDetect
    end

    if Rails::VERSION::MAJOR >= 3
      initializer "mobile-fu.action_controller" do |app|
        ActiveSupport.on_load :action_controller do
          include ActionController::MobileFu
        end
      end

      initializer "mobile-fu.action_view" do |app|
        ActiveSupport.on_load :action_view do
          include MobileFu::Helper
          alias_method_chain :stylesheet_link_tag, :mobilization
        end
      end
    end

    Mime::Type.register_alias "text/html", :mobile
    Mime::Type.register_alias "text/html", :tablet
  end
end

module ActionController
  module MobileFu

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Add this to one of your controllers to use MobileFu.
      #
      #    class ApplicationController < ActionController::Base
      #      has_mobile_fu
      #    end
      #
      # If you don't want mobile_fu to set the request format automatically,
      # you can pass false here.
      #
      #    class ApplicationController < ActionController::Base
      #      has_mobile_fu false
      #    end
      #
      def has_mobile_fu(allow_mobile = true)
        include ActionController::MobileFu::InstanceMethods

        before_filter :set_allowed_views

        helper_method :is_mobile_device?
        helper_method :is_tablet_device?
        helper_method :in_mobile_view?
        helper_method :in_tablet_view?
        helper_method :is_device?
        helper_method :mobile_device
        helper_method :mobile_enabled?
        helper_method :has_mobile_version?
      end

      # Add this to your controllers to prevent the mobile format from being set for specific actions
      #   class AwesomeController < ApplicationController
      #     has_no_mobile_fu_for :index
      #
      #     def index
      #       # Mobile format will not be set, even if user is on a mobile device
      #     end
      #
      #     def show
      #       # Mobile format will be set as normal here if user is on a mobile device
      #     end
      #   end
      def has_no_mobile_fu_for(*actions)
        @mobile_exempt_actions = actions
      end

      # Add this to your controllers to only let those actions use the mobile format
      # this method has priority over the #has_no_mobile_fu_for
      #   class AwesomeController < ApplicationController
      #     has_mobile_fu_for :index
      #
      #     def index
      #       # Mobile format will be set as normal here if user is on a mobile device
      #     end
      #
      #     def show
      #       # Mobile format will not be set, even if user is on a mobile device
      #     end
      #   end
      def has_mobile_fu_for(*actions)
        @mobile_include_actions = actions
      end
    end

    module InstanceMethods
      # Determines the request format based on whether the device is mobile or if
      # the user has opted to use either the 'Standard' view or 'Mobile' view or
      # 'Tablet' view.

      def set_allowed_views
        if has_mobile_version?
          if is_tablet_device?
            prepend_view_path tablet_views_path
            if (request.formats.first == Mime::HTML) || (request.formats.first == Mime::ALL)
              request.formats.prepend(Mime::TABLET)
            end
          elsif is_mobile_device?
            prepend_view_path mobile_views_path
            if (request.formats.first == Mime::HTML) || (request.formats.first == Mime::ALL)
              request.formats.prepend(Mime::MOBILE)
            end
          end
        else
          if (request.formats.first == Mime::MOBILE) || (request.formats.first == Mime::TABLET)
            request.formats = [:html]
          end
        end
      end

      def is_tablet_device?
        ::MobileFu::Tablet.is_a_tablet_device? request.user_agent
      end

      def is_mobile_device?
        !is_tablet_device? && !!mobile_device
      end

      def mobile_device
        request.headers['X_MOBILE_DEVICE']
      end

      def has_mobile_version?
        mobile_enabled? && mobile_action? && !request.xhr?
      end

      def mobile_enabled?
        raise "You must owerride this method"
        # false
      end

      # Can check for a specific user agent
      # e.g., is_device?('iphone') or is_device?('mobileexplorer')

      def is_device?(type)
        request.user_agent.to_s.downcase.include? type.to_s.downcase
      end

      def mobile_views_path
        @@mobile_views_path ||= [File.join(Rails.root, 'app', 'views_mobile')]
      end

      def tablet_views_path
        @@tablet_views_path ||= [File.join(Rails.root, 'app', 'views_tablet')]
      end

      # Returns true if current action is supposed to use mobile format
      # See #has_mobile_fu_for
      def mobile_action?
        if self.class.instance_variable_get("@mobile_include_actions").nil? #Now we know we dont have any includes, maybe excludes?
          return !mobile_exempt?
        else
          self.class.instance_variable_get("@mobile_include_actions").try(:include?, params[:action].try(:to_sym))
        end
      end

      # Returns true if current action isn't supposed to use mobile format
      # See #has_no_mobile_fu_for
      def mobile_exempt?
        self.class.instance_variable_get("@mobile_exempt_actions").try(:include?, params[:action].try(:to_sym))
      end
    end
  end
end

if Rails::VERSION::MAJOR < 3
  ActionController::Base.send :include, ActionController::MobileFu
  ActionView::Base.send :include, MobileFu::Helper
  ActionView::Base.send :alias_method_chain, :stylesheet_link_tag, :mobilization
end
