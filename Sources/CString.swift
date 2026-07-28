//
//  CString.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-27.
//

public struct FdtStringList : ~Escapable {
	public let bytes: RawSpan

	@_lifetime(copy bytes)
	public init(bytes: RawSpan) {
		self.bytes = bytes
	}

	@_lifetime(copy self)
	public func makeIterableIterator() -> FdtStringsIter {
		FdtStringsIter(bytes: bytes)
	}
}

public struct FdtStringsIter : ~Escapable {
	var bytes: RawSpan

	@_lifetime(copy self)
	@usableFromInline
	mutating func _next() -> RawSpan? {
		for i in bytes.byteOffsets where bytes[i] == 0 {
			let str = bytes.extracting(first: i)
			bytes = bytes.extracting(droppingFirst: i)
			return str
		}
		let str = bytes
		bytes = bytes.extracting(droppingFirst: bytes.byteCount)
		return str
	}

	@_lifetime(copy self)
	public mutating func next() -> UTF8Span? {
		guard let result = _next() else { return nil }
		let span = Span<UInt8>(_bytes: result)
		return UTF8Span(unchecked: span)
	}
}
