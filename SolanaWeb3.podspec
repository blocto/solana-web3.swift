Pod::Spec.new do |s|
  s.name             = 'SolanaWeb3'
  s.version          = '0.0.2'
  s.summary          = 'Solana web3 Swift API'
  s.description      = <<-DESC
                       The SolanaWeb3 swift library aims to provide complete coverage of Solana. The library was built on top of the Solana JSON RPC API.
                       DESC

  s.homepage         = 'https://github.com/portto/solana-web3.swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Scott' => 'scott@portto.com' }
  s.source           = { :git => 'https://github.com/portto/solana-web3.swift.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/BloctoApp'

  s.swift_version = '5.0'
  s.ios.deployment_target = '11.0'

  s.source_files = 'Sources/**/*'

  s.dependency 'CryptoSwift', '~> 1.4'
  s.dependency 'TweetNacl'
  s.dependency 'Runtime', '~> 2.2'
  s.dependency 'Alamofire', '~> 5.5'
end
