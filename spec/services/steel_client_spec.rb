require "rails_helper"

RSpec.describe SteelClient do
  it "only accepts a Steel address on the private network" do
    %w[http://steel.railway.internal:3000 http://localhost:3000 http://10.0.0.7:3000 http://[fd12::7]:3000]
      .each { |url| expect { described_class.new(url) }.not_to raise_error, url }

    %w[https://steel.example.com http://93.184.216.34:3000 http://steel.internal.example.com]
      .each { |url| expect { described_class.new(url) }.to raise_error(ArgumentError), url }
  end
end
