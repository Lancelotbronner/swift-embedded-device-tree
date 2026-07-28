//
//  FdtFormat.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-27.
//

public struct FdtHeader: BitwiseCopyable {
	/// This field shall contain the value `0xd00dfeed` (big-endian).
	public var magic: UInt32
	/// This field shall contain the total size in bytes of the devicetree data structure.
	///
	/// This size shall encompass all sections of the structure: the header, the memory reservation block, structure block and strings block, as well as any free space gaps between the blocks or after the final block.
	public var totalsize: UInt32
	/// This field shall contain the offset in bytes of the structure block (see Section 5.4) from the beginning of the header.
	public var off_dt_struct: UInt32
	/// This field shall contain the offset in bytes of the strings block (see Section 5.5) from the beginning of the header.
	public var off_dt_strings: UInt32
	/// This field shall contain the offset in bytes of the memory reservation block (see Section 5.3) from the beginning of the header.
	public var off_mem_rsvmap: UInt32
	/// This field shall contain the version of the devicetree data structure.
	///
	/// The version is 17 if using the structure as defined in this document.
	/// An DTSpec boot program may provide the devicetree of a later version, in which case this field shall contain the version number defined in whichever later document gives the details of that version.
	public var version: UInt32
	/// This field shall contain the lowest version of the devicetree data structure with which the version used is backwards compatible.
	///
	/// So, for the structure as defined in this document (version 17), this field shall contain 16 because version 17 is backwards compatible with version 16, but not earlier versions.
	/// As per Section 5.1, a DTSpec boot program should provide a devicetree in a format which is backwards compatible with version 16, and thus this field shall always contain 16.
	public var last_comp_version: UInt32
	/// This field shall contain the physical ID of the system’s boot CPU.
	///
	/// It shall be identical to the physical ID given in the reg property of that CPU node within the devicetree.
	public var boot_cpuid_phys: UInt32
	/// This field shall contain the length in bytes of the strings block section of the devicetree blob.
	public var size_dt_strings: UInt32
	/// This field shall contain the length in bytes of the structure block section of the devicetree blob.
	public var size_dt_struct: UInt32

	@inlinable
	public init(magic: UInt32, totalsize: UInt32, off_dt_struct: UInt32, off_dt_strings: UInt32, off_mem_rsvmap: UInt32, version: UInt32, last_comp_version: UInt32, boot_cpuid_phys: UInt32, size_dt_strings: UInt32, size_dt_struct: UInt32) {
		self.magic = magic
		self.totalsize = totalsize
		self.off_dt_struct = off_dt_struct
		self.off_dt_strings = off_dt_strings
		self.off_mem_rsvmap = off_mem_rsvmap
		self.version = version
		self.last_comp_version = last_comp_version
		self.boot_cpuid_phys = boot_cpuid_phys
		self.size_dt_strings = size_dt_strings
		self.size_dt_struct = size_dt_struct
	}
}

public struct FdtPropertyHeader: BitwiseCopyable {
	public var len: UInt32
	public var nameoff: UInt32

	@inlinable
	public init(len: UInt32, nameoff: UInt32) {
		self.len = len
		self.nameoff = nameoff
	}

	@inlinable
	public var byteSwapped: FdtPropertyHeader {
		FdtPropertyHeader(len: len.byteSwapped, nameoff: nameoff.byteSwapped)
	}
}
