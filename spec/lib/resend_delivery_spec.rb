require "rails_helper"
require "mail"

RSpec.describe ResendDelivery do
  let(:mail) do
    Mail.new(from: "Book Shelf <no-reply@bshelf.org>", to: "reader@example.com", subject: "Confirm").tap do |m|
      m.text_part = Mail::Part.new(body: "plain")
      m.html_part = Mail::Part.new(content_type: "text/html; charset=UTF-8", body: "<p>html</p>")
    end
  end

  it "posts the mail to the Resend API" do
    sent = stub_request(:post, "https://api.resend.com/emails")
      .with(headers: { "Authorization" => "Bearer re_test" },
        body: { from: "Book Shelf <no-reply@bshelf.org>", to: [ "reader@example.com" ], subject: "Confirm", html: "<p>html</p>", text: "plain" })

    described_class.new(api_key: "re_test").deliver!(mail)

    expect(sent).to have_been_requested
  end

  it "raises when Resend rejects the mail so the job retries" do
    stub_request(:post, "https://api.resend.com/emails").to_return(status: 422, body: "{}")

    expect { described_class.new(api_key: "re_test").deliver!(mail) }.to raise_error(/Resend 422/)
  end
end
