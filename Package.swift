// swift-tools-version: 6.4

import PackageDescription

let package = Package(
	name: "swift-embedded-device-tree",
	platforms: [
		.macOS(.v27),
	],
	products: [
		.library(name: "EmbeddedDeviceTree", targets: ["EmbeddedDeviceTree"]),
	],
	targets: [
		.target(
			name: "EmbeddedDeviceTree",
			swiftSettings: [
				.enableExperimentalFeature("BorrowingSequence"),
//				.enableExperimentalFeature("Embedded"),
				.enableExperimentalFeature("Lifetimes"),
				.enableExperimentalFeature("NoImplicitCopy"),
				.treatWarning("EmbeddedRestrictions", as: .error),
			],
		),
		.testTarget(
			name: "EmbeddedDeviceTreeTests",
			dependencies: [
				"EmbeddedDeviceTree",
			],
			resources: [
				.copy("dtb"),
			]
		),
	]
)
