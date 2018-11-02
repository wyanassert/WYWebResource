#
#  Be sure to run `pod spec lint WYWebResource.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  These will help people to find your library, and whilst it
  #  can feel like a chore to fill in it's definitely to your advantage. The
  #  summary should be tweet-length, and the description more in depth.
  #

  s.name         = "WYWebResource"
  s.version      = "1.0.3"
  s.summary      = "Download and unzip resource from web server."

  s.homepage     = "https://github.com/wyanassert/WYWebResource"

  s.license      = "MIT"

  s.author             = { "wyanassert" => "wyanassert@gmail.com" }
  s.social_media_url   = "http://twitter.com/wyanassert"

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/wyanassert/WYWebResource.git", :tag => "#{s.version}" }

  s.source_files  = "Core", "Core/**/*.{h,m}"
  s.public_header_files = "Core/**/*.h"

  # s.requires_arc = true
  s.dependency "SSZipArchive"
  s.dependency "AFNetworking"

end
