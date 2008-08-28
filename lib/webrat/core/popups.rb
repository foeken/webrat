module Webrat

  class Popup

    BUTTON_OK     = "OK"
    BUTTON_CANCEL = "CANCEL"

    def press_button button=BUTTON_OK
      return
    end

  end

  class Confirm < Popup

    attr_reader :message
    attr_reader :link
    attr_reader :method

    def initialize(message, link, method)
      @message  = message
      @link     = link
      @method   = method
    end

    def press_button button=BUTTON_OK
      case button
        when BUTTON_OK
          link.click(method, :confirm_popup => true)
        when BUTTON_CANCEL
          return
        else
          flunk("Cannot find that button")
      end
    end
  end

  class FormConfirm < Confirm

    attr_reader :form
    def initialize(message, form)
      @form = form
    end

    def press_button button=BUTTON_OK
      case button
        when BUTTON_OK
          form.submit
        when BUTTON_CANCEL
          return
        else
          flunk("Cannot find that button")
      end
    end

  end

end