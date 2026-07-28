//
//  FdtCursor.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-28.
//

public struct FdtCursor : ~Escapable {
	@usableFromInline let fdt: Fdt
	@usableFromInline var offset: UInt
	@usableFromInline var depth: UInt = 0

	@_lifetime(copy fdt)
	init(at offset: UInt, of fdt: Fdt) {
		self.fdt = fdt
		self.offset = offset
	}

	var byte: UInt8 {
		fdt.bytes[Int(bitPattern: offset)]
	}

	@usableFromInline
	mutating func align() {
		offset = offset.roundedUp(toMultipleOf: FDT_TAGSIZE)
	}

	@usableFromInline
	mutating func skipToChildren() throws(Fdt.ParsingError) {
		while true {
			let token = try token
			switch token {
			case .begin_node, .end_node: return
			default: try skip()
			}
		}
	}

	@_lifetime(copy self)
	@usableFromInline
	mutating func string() throws(Fdt.ParsingError) -> UTF8Span {
		let start = offset
		while byte != 0 {
			offset += 1
			if !fdt.bytes.byteOffsets.contains(Int(bitPattern: offset)) {
				throw Fdt.ParsingError(.invalidString, at: offset)
			}
		}
		let bytes = fdt.bytes.extracting(Int(bitPattern: start)...Int(bitPattern: offset))
		let span = Span<UInt8>(_bytes: bytes)
		let utf8 = UTF8Span(unchecked: span, isKnownASCII: true)
		return utf8
	}
}

public extension FdtCursor {
	@inlinable
	var token: FdtToken {
		get throws(Fdt.ParsingError) {
			let rawValue = fdt.bytes.load(fromByteOffset: Int(bitPattern: offset), as: UInt32.self, .bigEndian)
			guard let token = FdtToken(rawValue: rawValue) else {
				throw Fdt.ParsingError(.invalidToken(rawValue), at: offset)
			}
			return token
		}
	}

	@_lifetime(copy self)
	@inlinable
	mutating func next() throws(Fdt.ParsingError) -> FdtItem? {
		while true {
			let token = try token
			switch token {
			case .begin_node:
				offset += FDT_TAGSIZE
				depth += 1
				let name = try string()
				align()
				let node = FdtNode(named: name, at: self)
				return .node(node)
			case .prop:
				offset += FDT_TAGSIZE
				let prop = try FdtProperty(at: offset, of: fdt)
				offset += prop.size
				align()
				return .property(prop)
			case .end_node:
				offset += FDT_TAGSIZE
				if depth == 0 {
					throw Fdt.ParsingError(.badToken(.end_node), at: offset)
				}
				depth -= 1
			case .nop:
				offset += FDT_TAGSIZE
			case .end:
				if depth > 0 {
					throw Fdt.ParsingError(.badToken(.end), at: offset)
				}
				return nil
			}
		}
	}

	@inlinable
	mutating func skip() throws(Fdt.ParsingError) {
		_ = try next()
	}
}

public enum FdtItem : ~Escapable {
	case property(FdtProperty)
	case node(FdtNode)
}

public extension FdtItem {
	var isProperty: Bool {
		if case .property = self { return true } else { return false }
	}

	var isNode: Bool {
		if case .node = self { return true } else { return false }
	}

	var property: FdtProperty? {
		@_lifetime(copy self)
		get {
			if case let .property(prop) = self { return prop } else { return nil }
		}
		set {
			if let newValue { self = .property(newValue) }
		}
	}

	var node: FdtNode? {
		@_lifetime(copy self)
		get {
			if case let .node(prop) = self { return prop } else { return nil }
		}
		set {
			if let newValue { self = .node(newValue) }
		}
	}
}
