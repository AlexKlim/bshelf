source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.6"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_queue", "~> 1.7"
gem "devise", "~> 5.0"
gem "doorkeeper", "6.0.0.rc2"
gem "mcp", "~> 1.8"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.5"
end

group :development do
  gem "letter_opener", "~> 1.10"
end
