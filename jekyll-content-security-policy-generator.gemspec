lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "jekyll-content-security-policy-generator/version"
Gem::Specification.new do |spec|
  spec.name          = "jekyll-content-security-policy-generator"
  spec.summary       = "Helps generate a content security policy."
  spec.description   = "Helps generate a content security policy. Locates inline scripts, images, frames etc."
  spec.version       = JekyllContentSecurityPolicyGenerator::VERSION
  spec.authors       = ["strongscot"]
  spec.email         = ["mail@strongscot.com"]
  spec.homepage      = "https://github.com/strongscot/jekyll-content-security-policy-generator"
  spec.licenses      = ["MIT"]
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r!^(test|spec|features)/!)  }
  spec.require_paths = ["lib"]
  spec.add_dependency "jekyll"
  spec.add_dependency "nokogiri"
  spec.add_dependency "digest"
  spec.add_development_dependency "rake",
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop"
end
