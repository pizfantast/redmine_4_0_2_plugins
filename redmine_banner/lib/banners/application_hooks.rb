module Banners
  class BannerHeaderHooks < Redmine::Hook::ViewListener
    include ApplicationHelper
    include BannerHelper

    def view_layouts_base_html_head(_context = {})
      o = stylesheet_link_tag('banner', plugin: 'redmine_banner')
      o << javascript_include_tag('banner', plugin: 'redmine_banner')
      o
    end
  end

  #
  # for Project Banner
  #
  class ProjectBannerMessageHooks < Redmine::Hook::ViewListener
    def view_layouts_base_content(context = {})
      project = context[:project]
      return unless Banners::BannerHelper.enabled?(project)

      banner = Banner.where(project_id: project.id).first
      return '' unless banner && banner.enable_banner?

      display_part = banner.display_part
      return '' unless Banners::BannerHelper.action_to_display?(context[:controller], display_part)

      locals_params = { display_part: display_part, banner: banner }
      context[:controller].send(
        :render_to_string, partial: 'banner/project_body_bottom', locals: locals_params
      )
    end
  end

  class BannerMessageHooks < Redmine::Hook::ViewListener
    include BannerHelper

    # Override for conditional render_on
    # Ref. http://www.redmine.org/boards/3/topics/4316
    #
    def self.render_on(hook, options = {})
      define_method hook do |context|
        context[:controller].send(:render_to_string, { locals: context }.merge(options)) if !options.include?(:if) || evaluate_if_option(options[:if], context)
      end
    end

    def pass_timer?(_context)
      banner_setting = Setting.plugin_redmine_banner
      return true unless banner_setting['use_timer'] == 'true'

      now = Time.now
      start_date = get_time(
        banner_setting['start_ymd'],
        banner_setting['start_hour'],
        banner_setting['start_min']
      )

      end_date = get_time(
        banner_setting['end_ymd'],
        banner_setting['end_hour'],
        banner_setting['end_min']
      )
      now.between?(start_date, end_date)
    end

    def should_display_header?(context)
      # When Disabled, false.
      return false if Setting.plugin_redmine_banner['display_part'] == 'footer'

      pass_timer?(context)
    end

    def should_display_footer?(context)
      # When Disabled, false.
      return false if Setting.plugin_redmine_banner['display_part'] == 'header'

      pass_timer?(context)
    end

    render_on :view_layouts_base_body_bottom, partial: 'banner/body_bottom',
                                              if: :should_display_footer?

    private

    def evaluate_if_option(if_option, context)
      return false unless should_display(context)

      case if_option
      when Symbol
        send(if_option, context)
      when Method, Proc
        if_option.call(context)
      end
    end

    def should_display(context)
      banner_setting = Setting.plugin_redmine_banner
      return false if ((context[:controller].class.name != 'AccountController') &&
          (context[:controller].action_name != 'login')) &&
                      (banner_setting['display_only_login_page'] == 'true')

      return false if !User.current.logged? && banner_setting['only_authenticated'] == 'true'
      return false unless banner_setting['enable'] == 'true'

      true
    end
  end

  # TODO: view_layouts_base_after_top_menu is not supported Redmine itself.
  # Now use javascript to insert after top-menu. (Submitted ticket: http://www.redmine.org/issues/9915)
  class BannerTopMenuHooks < BannerMessageHooks
    render_on :view_layouts_base_body_bottom, partial: 'banner/after_top_menu',
                                              if: :should_display_header?
  end
end
