module Webrat
  class Link
    
    def initialize(session, element)
      @session  = session
      @element  = element
    end
    
    def click(method = nil, options = {})
      method ||= http_method
      return if href =~ /^#/ && method == :get
      
      options[:javascript] = true if options[:javascript].nil?
      
      if options[:javascript]
        
        unless options[:confirm_popup]
          confirm_match = onclick.match(/confirm\(['"](.*)['"]\)/i) if onclick
          if confirm_match
            confirm_text  = confirm_match[1]
            @session.show_confirm_popup(confirm_text,self,method)
            return
          end
        end
        
        @session.request_page(absolute_href, method, data)
      else
        @session.request_page(absolute_href, :get, {})
      end
    end
    
    def matches_text?(link_text)
      html = text.gsub('&nbsp;',' ')
      matcher = /#{Regexp.escape(link_text.to_s)}/i
      html =~ matcher || title =~ matcher
    end
    
    def matches_href?(href_text)
      href.downcase == href_text.downcase
    end
    
    def matches_method?(method=:get)
      http_method == method
    end
    
    def text
      @element.innerHTML
    end
    
  protected
  
    def data
      authenticity_token.blank? ? {} : {"authenticity_token" => authenticity_token}
    end

    def title
      @element['title']
    end

    def href
      @element["href"]
    end

    def absolute_href
      if href =~ %r{^https?://www.example.com(/.*)}
        $LAST_MATCH_INFO.captures.first
      elsif href =~ /^\?/
        "#{@session.current_url}#{href}"
      elsif href !~ /^\//
        "#{@session.current_url}/#{href}"
      else
        href
      end
    end
    
    def authenticity_token
      return unless onclick && onclick.include?("s.setAttribute('name', 'authenticity_token');") &&
        onclick =~ /s\.setAttribute\('value', '([a-f0-9]{40})'\);/
      $LAST_MATCH_INFO.captures.first
    end
    
    def onclick
      @element["onclick"]
    end
    
    def http_method
      if !onclick.blank? && ( onclick.include?("f.submit()") || onclick.include?("Ajax.Request") )
        http_method_from_js_form
      else
        :get
      end
    end

    def http_method_from_js_form
      if onclick.include?("m.setAttribute('name', '_method')")
        http_method_from_fake_method_param
      elsif onclick.include?("Ajax.Request")
        http_method_from_ajax_request_hash
      else
        :post
      end
    end

    def http_method_from_ajax_request_hash
      if onclick.include?("method:'delete'")
        :delete
      elsif onclick.include?("method:'post'")
        :post
      elsif onclick.include?("method:'put'")
        :put
      else
        raise "No HTTP method for method param in #{onclick.inspect}"
      end
    end

    def http_method_from_fake_method_param
      if onclick.include?("m.setAttribute('value', 'delete')")
        :delete
      elsif onclick.include?("m.setAttribute('value', 'put')")
        :put
      else
        raise "No HTTP method for _method param in #{onclick.inspect}"
      end
    end

  end
end
