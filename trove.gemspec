require_relative "lib/trove/version"

Gem::Specification.new do |spec|
  spec.name          = "trove"
  spec.version       = Trove::VERSION
  spec.summary       = "Deploy machine learning models in Ruby (and Rails)"
  spec.homepage      = "https://github.com/ankane/trove"
  spec.license       = "MIT"

  spec.author        = "Andrew Kane"
  spec.email         = "andrew@ankane.org"

  spec.files         = Dir["*.{md,txt}", "{exe,lib}/**/*"]
  spec.require_path  = "lib"

  spec.bindir        = "exe"
  spec.executables   = ["trove"]

  spec.required_ruby_version = ">= 3"

  spec.add_dependency "aws-sdk-s3"
  spec.add_dependency "rexml" # for aws-sdk-s3
  spec.add_dependency "thor"
end
