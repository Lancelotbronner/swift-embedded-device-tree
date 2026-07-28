//
//  AddressSpace.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-28.
//

/// The `#address-cells` and `#size-cells` properties of a node.
public struct AddressSpaceProperties : Sendable {
	/// The `#address-cells` property.
	public var address_cells: UInt32
	/// The `#size-cells` property.
	public var size_cells: UInt32
}

public extension AddressSpaceProperties {
	static let `default` = AddressSpaceProperties(address_cells: 0, size_cells: 0)
}
