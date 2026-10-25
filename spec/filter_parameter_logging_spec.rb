require "rails_helper"

RSpec.describe "Filtered parameters" do
  it "keeps search queries and PKCE verifiers out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("q" => "Solaris", "code_verifier" => "abc", "request_id" => "1"))
      .to eq("q" => "[FILTERED]", "code_verifier" => "[FILTERED]", "request_id" => "1")
  end
end
