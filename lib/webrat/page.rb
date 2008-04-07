require "hpricot"
require "English"

module Webrat
  class Page
    include Logging

    attr_reader :session
    attr_reader :url
    
    def initialize(session, url = nil, method = :get, data = {})
      @session  = session
      @url      = url
      @method   = method
      @data     = data
      
      reset_dom
      reloads if @url
    end
    
    # Verifies an input field or textarea exists on the current page, and stores a value for
    # it which will be sent when the form is submitted.
    #
    # Examples:
    #   fills_in "Email", :with => "user@example.com"
    #   fills_in "user[email]", :with => "user@example.com"
    #
    # The field value is required, and must be specified in <tt>options[:with]</tt>.
    # <tt>field</tt> can be either the value of a name attribute (i.e. <tt>user[email]</tt>)
    # or the text inside a <tt><label></tt> element that points at the <tt><input></tt> field.
    def fills_in(id_or_name_or_label, options = {})
      field = find_field(id_or_name_or_label, TextField, TextareaField)
      flunk("Could not find text or password input or textarea #{id_or_name_or_label.inspect}") if field.nil?
      field.set(options[:with])
    end

    # Verifies that an input checkbox exists on the current page and marks it
    # as checked, so that the value will be submitted with the form.
    #
    # Example:
    #   checks 'Remember Me'
    def checks(id_or_name_or_label)
      field = find_field(id_or_name_or_label, CheckboxField)
      flunk("Could not find checkbox #{id_or_name_or_label.inspect}") if field.nil?
      field.check
    end

    # Verifies that an input checkbox exists on the current page and marks it
    # as unchecked, so that the value will not be submitted with the form.
    #
    # Example:
    #   unchecks 'Remember Me'
    def unchecks(id_or_name_or_label)
      field = find_field(id_or_name_or_label, CheckboxField)
      flunk("Could not find checkbox #{id_or_name_or_label.inspect}") if field.nil?
      field.uncheck
    end

    # Verifies that an input radio button exists on the current page and marks it
    # as checked, so that the value will be submitted with the form.
    #
    # Example:
    #   chooses 'First Option'
    def chooses(field)
      radio = find_field_by_name_or_label(field)
      flunk("Could not find radio button #{field.inspect}") if radio.nil?
      flunk("Input #{radio.inspect} is not a radio button") unless radio['type'] == 'radio'
      add_form_data(radio, radio["value"] || "on")
    end

    # Verifies that a an option element exists on the current page with the specified
    # text. You can optionally restrict the search to a specific select list by
    # assigning <tt>options[:from]</tt> the value of the select list's name or
    # a label. Stores the option's value to be sent when the form is submitted.
    #
    # Examples:
    #   selects "January"
    #   selects "February", :from => "event_month"
    #   selects "February", :from => "Event Month"
    def selects(option_text, options = {})
      id_or_name_or_label = options[:from]
      field = find_field(id_or_name_or_label, SelectField)
      flunk("Could not find select #{id_or_name_or_label.inspect}") if field.nil?
      option = field.find_option(option_text)
      flunk("Could not find option #{option_text.inspect}") if option.nil?
      option.choose
    end

    # Saves the currently loaded page out to RAILS_ROOT/tmp/ and opens it in the default
    # web browser if on OS X. Useful for debugging.
    # 
    # Example:
    #   save_and_open
    def save_and_open
      return unless File.exist?(RAILS_ROOT + "/tmp")

      filename = "webrat-#{Time.now.to_i}.html"
      File.open(RAILS_ROOT + "/tmp/#{filename}", "w") do |f|
        f.write response.body
      end
      `open tmp/#{filename}`
    end

    # Issues a request for the URL pointed to by a link on the current page,
    # follows any redirects, and verifies the final page load was successful.
    #
    # clicks_link has very basic support for detecting Rails-generated 
    # JavaScript onclick handlers for PUT, POST and DELETE links, as well as
    # CSRF authenticity tokens if they are present.
    #
    # Example:
    #   clicks_link "Sign up"
    def clicks_link(link_text)
      link = find_link(link_text)
      link.click
    end

    # # Works like clicks_link, but only looks for the link text within a given selector
    # # 
    # # Example:
    # #   clicks_link_within "#user_12", "Vote"
    # def clicks_link_within(selector, link_text)
    #   clicks_one_link_of(links_within(selector), link_text)
    # end

    # Works like clicks_link, but forces a GET request
    # 
    # Example:
    #   clicks_get_link "Log out"
    def clicks_get_link(link_text)
      link = find_link(link_text)
      link.click(:get)
    end

    # Works like clicks_link, but issues a DELETE request instead of a GET
    # 
    # Example:
    #   clicks_delete_link "Log out"
    def clicks_delete_link(link_text)
      link = find_link(link_text)
      link.click(:delete)
    end

    # Works like clicks_link, but issues a POST request instead of a GET
    # 
    # Example:
    #   clicks_post_link "Vote"
    def clicks_post_link(link_text)
      link = find_link(link_text)
      link.click(:post)
    end

    # Works like clicks_link, but issues a PUT request instead of a GET
    # 
    # Example:
    #   clicks_put_link "Update profile"
    def clicks_put_link(link_text)
      link = find_link(link_text)
      link.click(:put)
    end

    # Verifies that a submit button exists for the form, then submits the form, follows
    # any redirects, and verifies the final page was successful.
    #
    # Example:
    #   clicks_button "Login"
    #   clicks_button
    #
    # The URL and HTTP method for the form submission are automatically read from the
    # <tt>action</tt> and <tt>method</tt> attributes of the <tt><form></tt> element.
    def clicks_button(value = nil)
      button = nil
      
      forms.each do |form|
        button = form.find_button(value)
        break if button
      end

      flunk("Could not find button #{value.inspect}") if button.nil?
      button.click
    end

    # Reloads the last page requested. Note that this will resubmit forms
    # and their data.
    #
    # Example:
    #   reloads
    def reloads
      request_page(@url, @method, @data)
    end

    def submits_form(form_id = nil) # :nodoc:
    end

  protected
    
    def find_link(text)
      
      matching_links = []
      
      links.each do |possible_link|
        matching_links << possible_link if possible_link.matches_text?(text)
      end
      
      if matching_links.any?
        matching_links.sort_by { |l| l.text.length }.first
      else
        flunk("Could not find link with text #{text.inspect}")
      end
    end
    
    def find_field(id_or_name_or_label, *field_types)
      forms.each do |form|
        result = form.find_field(id_or_name_or_label, *field_types)
        return result if result
      end
      
      nil
    end
    
    def request_page(url, method, data)
      debug_log "REQUESTING PAGE: #{method.to_s.upcase} #{url} with #{data.inspect}"
      
      session.send "#{method}_via_redirect", url, data || {}

      if response.body =~ /Exception caught/ || response.body.blank? 
        save_and_open
      end

      session.assert_response :success
      reset_dom
    end
    
    def response
      session.response
    end
    
    def reset_dom
      @dom    = nil
      @links  = nil
      @forms  = nil
    end
    
    def links
      return @links if @links
      
      @links = (dom / "a[@href]").map do |link_element|
        Link.new(self, link_element)
      end      
    end
    
    def forms
      return @forms if @forms
      
      @forms = (dom / "form").map do |form_element|
        Form.new(self, form_element)
      end
    end
      
    def dom # :nodoc:
      return @dom if defined?(@dom) && @dom
      flunk("You must visit a path before working with the page.") unless @session.response
      @dom = Hpricot(@session.response.body)
    end
    
    def flunk(message)
      raise message
    end
    
  end
end