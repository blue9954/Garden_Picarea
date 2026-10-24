// swift-tools-version: 6.0
// 앱 로직 하네스: SwiftUI/CoreLocation/WeatherKit 없이 App의 ViewModel·설정 코드를 Linux에서 컴파일·테스트한다.
// Sources/AppLogic의 *.swift 중 Shims.swift를 제외한 파일은 App/Sources로의 심볼릭 링크다.
import PackageDescription

let package = Package(
    name: "AppLogicHarness",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../Packages/GardenCore")],
    targets: [
        .target(name: "AppLogic", dependencies: [.product(name: "GardenCore", package: "GardenCore")]),
        .testTarget(name: "AppLogicTests", dependencies: ["AppLogic", .product(name: "GardenCore", package: "GardenCore")]),
    ]
)
