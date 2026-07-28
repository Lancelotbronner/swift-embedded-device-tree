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

	@_lifetime(copy name, copy bytes)
	init(name: UTF8Span, bytes: RawSpan) {
		self.name = name
		self.bytes = bytes
	}

	@_lifetime(copy fdt)
	@usableFromInline
	init(at offset: UInt, of fdt: Fdt) throws(Fdt.ParsingError) {
		let header = fdt.bytes
			.unsafeLoad(fromByteOffset: Int(bitPattern: offset), as: FdtPropertyHeader.self)
			.byteSwapped

		let nameBytes = try fdt.string(at: UInt(header.nameoff))
		let nameSpan = Span<UInt8>(_bytes: nameBytes)
		name = UTF8Span(unchecked: nameSpan, isKnownASCII: true)

		let valueOffset = offset + 3 * FDT_TAGSIZE
		bytes = fdt.bytes
			.extracting(droppingFirst: Int(valueOffset))
			.extracting(first: Int(header.len))
	}

	/// The size of this property in bytes.
	@usableFromInline
	var size: UInt {
		FDT_TAGSIZE + UInt(bitPattern: MemoryLayout<FdtPropertyHeader>.size + name.count + bytes.byteCount)
	}
}

public enum FdtPropertyError : Error {
	case invalidLength(expected: Int, got: Int)
}

public extension FdtProperty {
	@inlinable
	var span: Span<UInt8> {
		@_lifetime(copy self)
		get { Span(_bytes: bytes) }
	}

	@inlinable
	func unsafeLoad<T: BitwiseCopyable>(as type: T.Type) throws(FdtPropertyError) -> T {
		guard bytes.byteCount == MemoryLayout<T>.size else {
			throw .invalidLength(expected: MemoryLayout<T>.size, got: bytes.byteCount)
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
	func asString() throws(FdtPropertyError) -> UTF8Span {
		UTF8Span(unchecked: span, isKnownASCII: false)
	}

	@_lifetime(copy self)
	@inlinable
	func asStringList() throws(FdtPropertyError) -> FdtStringList {
		FdtStringList(bytes: bytes)
	}
}

public struct FdtProperties : ~Escapable {
	@usableFromInline let cursor: FdtCursor

	@_lifetime(copy cursor)
	@usableFromInline
	init(at cursor: FdtCursor) {
		self.cursor = cursor
	}
}

public extension FdtProperties {
	@_lifetime(copy self)
	@inlinable
	func makeIterableIterator() -> FdtPropIter {
		FdtPropIter(at: cursor)
	}
}

/// An iterator over the properties of a device tree node.
public struct FdtPropIter : ~Escapable {
	@usableFromInline var cursor: FdtCursor

	@_lifetime(copy cursor)
	@usableFromInline
	init(at cursor: FdtCursor) {
		self.cursor = cursor
	}
}

public extension FdtPropIter {
	@inlinable
	@_lifetime(copy self)
	mutating func next() throws(Fdt.ParsingError) -> FdtProperty? {
		while let item = try cursor.next() {
			switch item {
			case let .property(prop): return prop
			default: continue
			}
		}
		return nil
	}
}
