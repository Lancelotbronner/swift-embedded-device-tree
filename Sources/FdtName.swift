//
//  FdtName.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-28.
//

public struct FdtName : ~Escapable {
	public let bytes: RawSpan

	@_lifetime(copy bytes)
	@inlinable
	public init(bytes: RawSpan) {
		self.bytes = bytes
	}
}

public extension FdtName {
	var span: Span<UInt8> {
		@_lifetime(copy self)
		get { Span(viewing: bytes) }
	}

	var utf8: UTF8Span {
		@_lifetime(copy self)
		get { UTF8Span(unchecked: span.extracting(droppingLast: 1), isKnownASCII: true) }
	}

	var string: String {
		String(copying: utf8)
	}

	static func == (lhs: FdtName, rhs: StaticString) -> Bool {
		rhs.withUTF8Buffer { buffer in
			lhs.utf8.bytesEqual(to: buffer)
		}
	}
}
