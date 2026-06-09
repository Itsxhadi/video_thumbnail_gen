#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'video_thumbnail_gen'
  s.version          = '0.6.3'
  s.summary          = 'Flutter plugin for generating video thumbnails on Android and iOS.'
  s.description      = <<-DESC
A production-grade Flutter plugin for generating video thumbnails.
Supports JPEG, PNG, WebP, and HEIC formats with batch extraction,
video metadata, in-memory caching, and typed error handling.
                       DESC
  s.homepage         = 'https://github.com/Itsxhadi/video_thumbnail_gen'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hadi' => 'hadi7786x@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.pod_target_xcconfig = {
    'USER_HEADER_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/libwebp/**'
  }
  s.dependency 'Flutter'
  s.dependency 'libwebp'

  s.ios.deployment_target = '11.0'
end
