require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe "submissal of forms" do
  before do
    @session = Webrat::TestSession.new
  end

  it "should work with simple forms" do
    @session.response_body = <<-EOS
      <form method="post" action="/login">
        <label for="user_text">User Text</label>
        <textarea id="user_text" name="user[text]">filling text area</textarea>
        <input type="submit" />
      </form>
    EOS
    @session.should_receive(:request_page).with("/login", "post", "user" => {"text" => "filling text area"})
    @session.submits_form
  end

  it "should work with multiple forms" do
    @session.response_body = <<-EOS
      <form method="post" action="/login" id="form1">
        <label for="user_text">User Text</label>
        <textarea id="user_text" name="user[text]">filling text area 1</textarea>
        <input type="submit" />
      </form>
      <form method="post" action="/login" id="form2">
        <label for="user_text">User Text</label>
        <textarea id="user_text" name="user[text]">filling text area 2</textarea>
        <input type="submit" />
      </form>
    EOS
    @session.should_receive(:request_page).with("/login", "post", "user" => {"text" => "filling text area 1"})
    @session.submits_form("form1")

    @session.should_receive(:request_page).with("/login", "post", "user" => {"text" => "filling text area 2"})
    @session.submits_form("form2")

    lambda {
      @session.submits_form("form3")
    }.should raise_error

  end
end