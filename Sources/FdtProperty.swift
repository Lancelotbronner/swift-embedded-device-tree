//
//  FdtProperty.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-11.
//

/// A property of a device tree node.
public struct FdtProperty : ~Escapable {
	public let name: UTF8Span
	public let bytes: RawSpan
}

public enum FdtPropertyError : Error {
	case invalidLength(Int, Int)
}

public extension FdtProperty {
	@inlinable
	var span: Span<UInt8> {
		@_lifetime(copy self)
		get { Span(_bytes: bytes) }
	}

	func unsafeLoad<T: BitwiseCopyable>(as type: T.Type) throws(FdtPropertyError) -> T {
		guard bytes.byteCount == MemoryLayout<T>.size else {
			throw .invalidLength(bytes.byteCount, MemoryLayout<T>.size)
		}
		return bytes.unsafeLoad(as: T.self)
	}

	@inlinable
	func asUInt32() throws(FdtPropertyError) -> UInt32 {
		try self.unsafeLoad(as: UInt32.self).byteSwapped
	}

	@inlinable
	func asUInt64() throws(FdtPropertyError) -> UInt64 {
		try self.unsafeLoad(as: UInt64.self).byteSwapped
	}

	@_lifetime(copy self)
	@inlinable
	func asStr() throws(FdtPropertyError) -> UTF8Span {
		UTF8Span(unchecked: span, isKnownASCII: false)
	}

	@_lifetime(copy self)
	@inlinable
	func asStringList() throws(FdtPropertyError) -> FdtStringList {
		FdtStringList(bytes: bytes)
	}
}

public struct FdtProperties : ~Escapable {
	@usableFromInline let node: FdtNode

	@_lifetime(copy self)
	@inlinable
	public func makeIterableIterator() -> FdtPropIter {
		var offset = node.offset
		// Skip FDT_BEGIN_NODE
		offset += FDT_TAGSIZE
		offset = (try? node.fdt.find_string_end(from: offset)) ?? offset
		offset = Fdt.align_tag_offset(offset)
		return FdtPropIter(at: offset, in: node)
	}
}

/// An iterator over the properties of a device tree node.
public struct FdtPropIter : ~Escapable {
	@usableFromInline let node: FdtNode
	@usableFromInline var offset: UInt

	@_lifetime(copy node)
	@usableFromInline
	init(at offset: UInt, in node: FdtNode) {
		self.node = node
		self.offset = offset
	}

	@_lifetime(copy self)
	@usableFromInline
	mutating func find() throws(Fdt.ParsingError) -> FdtProperty? {
		while true {
			let token = try node.fdt.token(at: offset)
			switch token {
			case .prop: return try property(at: offset)
			case .nop: offset += FDT_TAGSIZE
			default: return nil
			}
		}
	}

	@_lifetime(copy self)
	@usableFromInline
	func property(at offset: UInt) throws(Fdt.ParsingError) -> FdtProperty {
		let header = node.fdt.bytes
			.unsafeLoad(fromByteOffset: Int(bitPattern: offset), as: FdtPropertyHeader.self)
			.byteSwapped

		let nameBytes = try node.fdt.string(at: UInt(header.nameoff))
		let nameSpan = Span<UInt8>(_bytes: nameBytes)
		let name = UTF8Span(unchecked: nameSpan, isKnownASCII: true)

		let valueOffset = offset + 3 * FDT_TAGSIZE
		let value = node.fdt.bytes
			.extracting(droppingFirst: Int(valueOffset))
			.extracting(first: Int(header.len))

		return FdtProperty(name: name, bytes: value)
	}

	@inlinable
	@_lifetime(copy self)
	public mutating func next() throws(Fdt.ParsingError) -> FdtProperty? {
		guard let result = try find() else { return nil }
		offset = try node.fdt.next_property_offset(from: offset, check_name: false)
		return result
	}
}
