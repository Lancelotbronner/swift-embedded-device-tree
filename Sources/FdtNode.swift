//
//  FdtNode.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-11.
//

/// A node in a flattened device tree.
public struct FdtNode : ~Escapable {
	@usableFromInline let fdt: Fdt
	@usableFromInline let offset: UInt
	/// The `#address-cells` and `#size-cells` properties of this node's parent node.
	@usableFromInline let parent_address_space: AddressSpaceProperties

	@_lifetime(copy fdt)
	@usableFromInline
	init(
		at offset: some FixedWidthInteger,
		in fdt: Fdt,
		space: AddressSpaceProperties = .default
	) {
		self.fdt = fdt
		self.offset = UInt(offset)
		self.parent_address_space = space
	}
}

public extension FdtNode {
	var name: UTF8Span {
		@_lifetime(copy self)
		get {
			let i = Fdt.StringIndex(offset: UInt32(offset))
			let bytes = fdt.strings[i]
			let span = Span<UInt8>(_bytes: bytes)
			let utf8 = UTF8Span(unchecked: span, isKnownASCII: true)
			return utf8
		}
	}

	var nameWithoutAddress: UTF8Span {
		@_lifetime(copy self)
		get {
			let name = name
			for i in name.span.indices {
				if name.span[i] == UInt8(ascii: "@") {
					return UTF8Span(unchecked: name.span.extracting(..<i), isKnownASCII: true)
				}
			}
			return name
		}
	}

	var children: FdtChildren {
		@_lifetime(copy self)
		get { FdtChildren(self) }
	}
}

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

public struct FdtChildren : ~Escapable {
	@usableFromInline let node: FdtNode

	@_lifetime(copy node)
	@usableFromInline
	init(_ node: FdtNode) {
		self.node = node
	}
}

public extension FdtChildren {
	@_lifetime(copy self)
	func makeIterableIterator() -> FdtChildIter {
		FdtChildIter.start(node)
	}
}

/// An iterator over the children of a device tree node.
public enum FdtChildIter : ~Escapable {
	case start(FdtNode)
	case running(Fdt, offset: UInt, space: AddressSpaceProperties)
}

public extension FdtChildIter {

	@_lifetime(copy self)
	@inlinable
	mutating func next() throws(Fdt.ParsingError) -> FdtNode? {
		switch self {
		case let .start(node):
			//TODO: move this setup to the FdtChildren initializer?
			var offset = node.offset
			// Skip FDT_BEGIN_NODE
			offset += FDT_TAGSIZE
			offset = try node.fdt.find_string_end(from: offset)
			offset = node.fdt.align_tag_offset(offset)
			self = .running(node.fdt, offset: offset, space: node.parent_address_space)
			return try next()
		case .running(let fdt, var offset, let space):
			while true {
				let token = try fdt.token(at: offset)
				switch token {
				case .begin_node:
					let node_offset = offset
					offset = try fdt.next_sibling_offset(from: offset)
					self = .running(fdt, offset: offset, space: space)
					return FdtNode(at: node_offset, in: fdt, space: space)
				case .prop:
					offset = try fdt.next_property_offset(from: offset + FDT_TAGSIZE, check_name: false)
					self = .running(fdt, offset: offset, space: space)
				case .end_node, .end:
					return nil
				case .nop:
					offset += FDT_TAGSIZE
				}
			}
		}
	}
}
