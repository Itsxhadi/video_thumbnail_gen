// swift-tools-version: 5.9
// VideoThumbnail — Swift Package Manager manifest
// Author : Hadi <hadi7786x@gmail.com>
// GitHub : https://github.com/Itsxhadi/video_thumbnail_gen
//
// ⚠️  WebP encoding is only available when integrating via CocoaPods (which
//     pulls in the libwebp dependency automatically).  When using SPM, WebP
//     output gracefully falls back to JPEG.  JPEG, PNG, and HEIC are fully
//     supported with SPM.

import PackageDescription

let package = Package(
    name: "VideoThumbnailGen",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(
            name: "VideoThumbnailGen",
            targets: ["VideoThumbnailGen"]
        ),
    ],
    targets: [
        .target(
            name: "VideoThumbnailGen",
            path: "ios/Classes",
            publicHeadersPath: ".",
            cSettings: [
                // Make the #import <Flutter/Flutter.h> resolvable when Xcode
                // injects the Flutter.xcframework search paths.
                .headerSearchPath("."),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("UIKit"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
            ]
        ),
    ]
)
