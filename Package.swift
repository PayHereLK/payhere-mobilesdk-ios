// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PayHereSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PayHereSDK",
            targets: ["PayHereSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.2"),
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", from: "4.2.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "PayHereSDK",
            dependencies: [
                "Alamofire",
                "ObjectMapper",
                "SDWebImage"
            ],
            path: "payHereSDK/Sources",
            exclude: [
                "Info.plist"
            ],
            resources: [
                .process("colors.xcassets"),
                .process("image.xcassets"),
                .process("PrivacyInfo.xcprivacy"),
                .process("Resources")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
