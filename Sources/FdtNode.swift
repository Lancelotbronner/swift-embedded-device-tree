//
//  FdtNode.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-11.
//

/// A node in a flattened device tree.
public struct FdtNode : ~Escapable {
	//TODO: let cursor: Ref<FdtCursor>
	//TODO: let parent: Ref<FdtNode>
	@usableFromInline let cursor: FdtCursor
	public let name: FdtName
	/// The `#address-cells` and `#size-cells` properties of this node's parent node.
	@usableFromInline let parent_address_space: AddressSpaceProperties

	@_lifetime(copy cursor, copy name)
	@usableFromInline
	init(
		named name: FdtName,
		at cursor: FdtCursor,
		space: AddressSpaceProperties = .default
	) {
		self.cursor = cursor
		self.name = name
		self.parent_address_space = space
	}

	@_lifetime(copy cursor)
	@usableFromInline
	init(
		at cursor: FdtCursor,
		space: AddressSpaceProperties = .default
	) throws(Fdt.ParsingError) {
		var cursor = cursor
		cursor.offset += FDT_TAGSIZE
		cursor.depth += 1
		name = FdtName(bytes: try cursor.string())
		cursor.align()
		self.cursor = cursor
		self.parent_address_space = space
	}
}

public extension FdtNode {
	var nameWithoutAddress: UTF8Span {
		@_lifetime(copy self)
		get {
			for i in name.span.indices {
				if name.span[i] == UInt8(ascii: "@") {
					return UTF8Span(unchecked: name.span.extracting(..<i), isKnownASCII: true)
				}
			}
			return name.utf8
		}
	}

	var children: FdtChildren {
		@_lifetime(copy self)
		get { FdtChildren(at: cursor) }
	}

	var properties: FdtProperties {
		@_lifetime(copy self)
		get { FdtProperties(at: cursor) }
	}

	@_lifetime(copy self)
	func property(_ name: StaticString) throws(Fdt.ParsingError) -> FdtProperty? {
		var iter = properties.makeIterableIterator()
		while let prop = try iter.next() {
			if prop.name == name {
				return prop
			}
		}
		return nil
	}

	@_lifetime(copy self)
	func child(_ name: StaticString) throws(Fdt.ParsingError) -> FdtNode? {
		var iter = children.makeIterableIterator()
		while let child = try iter.next() {
			if child.name == name {
				return child
			}
		}
		return nil
	}
}

public struct FdtChildren : ~Escapable {
	@usableFromInline var cursor: FdtCursor

	@_lifetime(copy cursor)
	@usableFromInline
	init(at cursor: FdtCursor) {
		self.cursor = cursor
	}
}

public extension FdtChildren {
	/// Optimize the internal state for multiple iterations.
	@inlinable
	mutating func prepare() throws(Fdt.ParsingError) {
		try cursor.skipToChildren()
	}

	@_lifetime(copy self)
	@inlinable
	func makeIterableIterator() -> FdtChildIter {
		FdtChildIter(cursor: cursor)
	}
}

/// An iterator over the children of a device tree node.
public struct FdtChildIter : ~Escapable {
	@usableFromInline var cursor: FdtCursor

	@_lifetime(copy cursor)
	@usableFromInline
	init(cursor: FdtCursor) {
		self.cursor = cursor
	}
}

public extension FdtChildIter {
	@_lifetime(copy self)
	@inlinable
	mutating func next() throws(Fdt.ParsingError) -> FdtNode? {
		while let item = try cursor.next() {
			switch item {
			case let .node(node): return node
			case .property: continue
			}
		}
		return nil
	}
}
