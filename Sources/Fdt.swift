//
//  Fdt.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-11.
//

// https://devicetree-specification.readthedocs.io/en/latest/chapter5-flattened-format.html
// https://docs.rs/dtoolkit/latest

/// Version of the FDT specification supported by this library.
public let FDT_VERSION: UInt32 = 17;

@usableFromInline
var FDT_TAGSIZE: UInt {
	UInt(bitPattern: MemoryLayout<UInt32>.size)
}

/// A read-only zero-copy view into a flattened device tree.
public struct Fdt : ~Escapable {
	@usableFromInline var bytes: RawSpan
}

public extension Fdt {
	@_lifetime(copy bytes)
	init(parsing bytes: RawSpan) throws(ParsingError) {
		// Ensure we at least have a header
		guard bytes.byteCount >= MemoryLayout<FdtHeader>.size else {
			throw ParsingError(.invalidLength, at: 0)
		}
		self.bytes = bytes
		self.bytes = bytes.extracting(first: Int(header.totalsize.byteSwapped))
		guard header.magic.byteSwapped == 0xd00dfeed else {
			throw ParsingError(.invalidMagic, at: \FdtHeader.magic)
		}
		guard header.totalsize.byteSwapped == bytes.byteCount else {
			throw ParsingError(.invalidLength, at: \FdtHeader.totalsize)
		}
		guard (header.last_comp_version.byteSwapped...header.version.byteSwapped).contains(FDT_VERSION) else {
			throw ParsingError(.unsupportedVersion(header.version.byteSwapped), at: \FdtHeader.version)
		}
	}

	var header: FdtHeader {
		//SAFETY: The initializer ensures we have at least enough bytes to represent a header.
		_read { yield bytes.unsafeLoad(as: FdtHeader.self) }
	}

	var cursor: FdtCursor {
		@_lifetime(copy self)
		get { FdtCursor(at: UInt(header.off_dt_struct.byteSwapped), of: self) }
	}

	var root: FdtNode {
		@_lifetime(copy self)
		get throws(Fdt.ParsingError) { try FdtNode(at: cursor) }
	}

	var mem_rsvmap: ReservedMemoryMap {
		@_lifetime(copy self)
		get {
			let header = header
			let bytes = bytes
				.extracting(first: Int(header.off_dt_struct.byteSwapped))
				.extracting(droppingFirst: Int(header.off_mem_rsvmap.byteSwapped))
			return ReservedMemoryMap(in: bytes)
		}
	}

	var strings: Strings {
		@_lifetime(copy self)
		get {
			let header = header
			let bytes = bytes
				.extracting(droppingFirst: Int(header.off_dt_strings.byteSwapped))
			return Strings(bytes: bytes)
		}
	}
}

public extension Fdt {
	struct ParsingError: Error {
		public let kind: Kind
		public let offset: UInt

		@usableFromInline
		init(_ kind: Kind, at offset: some FixedWidthInteger) {
			self.kind = kind
			self.offset = UInt(offset)
		}

		init<T>(_ kind: Kind, at keyPath: PartialKeyPath<T>) {
			self.kind = kind
			self.offset = UInt(bitPattern: MemoryLayout<T>.offset(of: keyPath) ?? 0)
		}

		public enum Kind: Sendable {
			/// if data is too short to contain a valid FDT header or if the totalsize field in the header does not match the length of data.
			case invalidLength
			/// if the magic field in the header is not 0xd00dfeed.
			case invalidMagic
			/// if the version field in the header is not supported by this library.
			case unsupportedVersion(UInt32)
			/// if the header fails to pass the header integrity checks.
			case invalidHeader(StaticString)
			case invalidString
			case invalidOffset
			case invalidNodeName
			case invalidPropertyName
			case invalidToken(UInt32)
			case badToken(FdtToken)
		}
	}

	//TODO: Turn into an Iterable to avoid pre-processing
	struct ReservedMemoryMap : ~Escapable {
		public let span: Span<ReservedMemoryEntry>

		@_lifetime(copy bytes)
		init(in bytes: RawSpan) {
			var span = Span<ReservedMemoryEntry>(_bytes: bytes)
			while span.count > 0, span[span.count - 1] == .zero {
				span = span.extracting(droppingLast: 1)
			}
			self.span = span
		}
	}

	struct ReservedMemoryEntry : BitwiseCopyable, Equatable {
		static var zero: Self { ReservedMemoryEntry(address: 0, size: 0) }
		var address: UInt64
		var size: UInt64
	}

	struct Property : ~Escapable {
		public let bytes: RawSpan
		public let name: StringIndex

		@_lifetime(&bytes)
		init(parsing bytes: inout RawSpan) {
			let (len, nameoff) = bytes.unsafeLoad(as: (UInt32, UInt32).self)
			bytes = bytes.extracting(droppingFirst: MemoryLayout<(UInt32, UInt32)>.size)
			name = StringIndex(offset: nameoff)
			self.bytes = bytes.extracting(first: Int(len))
		}
	}

	//TODO: Turn into an Iterable
	struct Strings : ~Escapable {
		public let bytes: RawSpan
	}

	struct StringIndex {
		let offset: UInt32
	}
}

public extension Fdt.Strings {
	subscript(position: Fdt.StringIndex) -> RawSpan {
		@_lifetime(copy self)
		get {
			let bytes = bytes.extracting(droppingFirst: Int(position.offset))
			for i in bytes.byteOffsets where bytes[i] == 0 {
				return bytes.extracting(first: i)
			}
			return RawSpan()
		}
	}

	@_lifetime(copy self)
	func makeIterableIterator() -> IterableIterator {
		.init(bytes: bytes)
	}

	struct IterableIterator : ~Escapable {
		@usableFromInline var bytes: RawSpan

		@_lifetime(copy bytes)
		@usableFromInline
		init(bytes: RawSpan) {
			self.bytes = bytes
		}
	}
}

public extension Fdt.Strings.IterableIterator {
	@_lifetime(copy self)
	@inlinable
	mutating func next() -> RawSpan? {
		for i in bytes.byteOffsets where bytes[i] == 0 {
			let str = bytes.extracting(first: i)
			bytes = bytes.extracting(droppingFirst: i + 1)
			return str
		}
		bytes = bytes.extracting(droppingFirst: bytes.byteCount)
		return bytes
	}
}

public enum FdtToken: UInt32, Sendable {
	case begin_node = 0x1
	case end_node = 0x2
	case prop = 0x3
	case nop = 0x4
	case end = 0x9
}

extension Fdt {
	@_lifetime(copy self)
	@usableFromInline
	func bytes(at offset: UInt) -> RawSpan {
		bytes.extracting(droppingFirst: Int(bitPattern: offset))
	}

	@usableFromInline
	func u8(at offset: UInt) -> UInt8 {
		bytes.load(fromByteOffset: Int(bitPattern: offset), as: UInt8.self)
	}

	@usableFromInline
	func u16(at offset: UInt, _ byteOrder: ByteOrder = .littleEndian) -> UInt16 {
		bytes.load(fromByteOffset: Int(bitPattern: offset), as: UInt16.self, byteOrder)
	}

	@usableFromInline
	func u32(at offset: UInt, _ byteOrder: ByteOrder = .littleEndian) -> UInt32 {
		bytes.load(fromByteOffset: Int(bitPattern: offset), as: UInt32.self, byteOrder)
	}

	@usableFromInline
	func token(at offset: UInt) throws(ParsingError) -> FdtToken {
		let rawValue = u32(at: offset, .bigEndian)
		guard let token = FdtToken(rawValue: rawValue) else {
			throw ParsingError(.invalidToken(rawValue), at: offset)
		}
		return token
	}

	func traverse(at offset: UInt, check_strings: Bool) throws(ParsingError) -> UInt {
		var offset = offset
		var depth = 0
		while true {
			let token = try token(at: offset)
			switch token {
			case .begin_node:
				depth += 1
				offset += FDT_TAGSIZE
				let end_offset = try find_string_end(from: offset)
				// Validate name
				if check_strings {
					let name = try string(at: offset, end: end_offset)
					if depth == 1 {
						if !name.isEmpty {
							throw ParsingError(.invalidNodeName, at: offset)
						}
					} else if name.isEmpty || true /* crate::validate::is_valid_node_name(name) */ {
						throw ParsingError(.invalidNodeName, at: offset)
					}
				}
				offset = Fdt.align_tag_offset(end_offset)
			case .end_node:
				if depth == 0 {
					throw ParsingError(.badToken(.end_node), at: offset)
				}
				depth -= 1
				offset += FDT_TAGSIZE
				if depth == 0 {
					// End of root node
					return offset
				}
			case .prop:
				offset += FDT_TAGSIZE
				offset = try next_property_offset(from: offset, check_name: check_strings)
			case .nop:
				offset += FDT_TAGSIZE
			case .end:
				throw ParsingError(.badToken(.end), at: offset)
			}
		}
	}

	@usableFromInline
	func skip_props(from offset: UInt) throws(ParsingError) -> UInt? {
		var offset = offset
		while true {
			let token = try token(at: offset)
			switch token {
			case .begin_node:
				return offset
			case .prop:
				offset = try next_property_offset(from: offset + FDT_TAGSIZE, check_name: false)
			case .end_node, .end:
				return nil
			case .nop:
				offset += FDT_TAGSIZE
			}
		}
	}

	//		/// Returns a string from the string block.
	//		pub(crate) fn string(self, string_block_offset: usize) -> Result<&'a str, FdtParseError> {
	//			let header = self.header();
	//			let str_block_start = header.off_dt_strings() as usize;
	//			let str_block_size = header.size_dt_strings() as usize;
	//			let str_block_end = str_block_start + str_block_size;
	//			let str_start = str_block_start + string_block_offset;
	//
	//			if str_start >= str_block_end {
	//				return Err(FdtParseError::new(FdtErrorKind::InvalidLength, str_start));
	//			}
	//
	//			self.string_at_offset(str_start, Some(str_block_end))
	//		}

	/// Returns a NUL-terminated string from a given offset.
	@_lifetime(copy self)
	func string(
		at offset: UInt,
		end: UInt? = nil,
	) throws(ParsingError) -> RawSpan {
		guard bytes.byteOffsets.contains(Int(bitPattern: offset)) else {
			throw ParsingError(.invalidOffset, at: offset)
		}
		let slice = if let end {
			bytes.extracting(Int(bitPattern: offset)...Int(bitPattern: end))
		} else {
			bytes.extracting(Int(bitPattern: offset)...)
		}
		//TODO: adjust to last null
		return slice
	}

	@usableFromInline
	func find_string_end(from start: UInt) throws(ParsingError) -> UInt {
		var offset = start
		repeat {
			if u8(at: offset) == 0 {
				return offset + 1
			}
			offset += 1
		} while bytes.byteOffsets.contains(Int(bitPattern: offset))
		throw ParsingError(.invalidString, at: start)
	}

	@usableFromInline
	func next_sibling_offset(from offset: UInt) throws(ParsingError) -> UInt {
		try traverse(at: offset, check_strings: false)
	}

	@usableFromInline
	func next_property_offset(
		from offset: UInt,
		check_name: Bool,
	) throws(ParsingError) -> UInt {
		let len = UInt(u32(at: offset, .bigEndian))

		if check_name {
			let nameoff_offset = offset + FDT_TAGSIZE;
			let nameoff = UInt(u32(at: nameoff_offset, .bigEndian))
			let name = try string(at: nameoff)
			//TODO: Validate property name
			//				if !crate::validate::is_valid_property_name(name) {
			//					return Err(FdtParseError::new(
			//						FdtErrorKind::InvalidPropertyName,
			//						offset + FDT_TAGSIZE,
			//					));
			//				}
		}

		let prop_offset = offset + 2 * FDT_TAGSIZE
		let end_offset = prop_offset + len
		if end_offset > bytes.byteCount {
			throw ParsingError(.invalidLength, at: prop_offset)
		}

		return Fdt.align_tag_offset(end_offset)
	}
	
	@usableFromInline
	static func align_tag_offset(_ offset: UInt) -> UInt {
		offset.roundedUp(toMultipleOf: FDT_TAGSIZE)
	}
}
