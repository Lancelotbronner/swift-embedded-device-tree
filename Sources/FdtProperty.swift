//
//  FdtProperty.swift
//  swift-embedded-device-tree
//
//  Created by Christophe Bronner on 2026-07-11.
//

/// A property of a device tree node.
public struct FdtProperty : ~Escapable {
	public let name: UTF8Span
	public let value: RawSpan
}

/// An iterator over the properties of a device tree node.
public enum FdtPropIter : ~Escapable {
	case start(Fdt, offset: UInt)
	case running(Fdt, offset: UInt)
}

/*
impl<'a> Iterator for FdtPropIter<'a> {
    type Item = FdtProperty<'a>;

    fn next(&mut self) -> Option<Self::Item> {
        match self {
            Self::Start { fdt, offset } => {
                let mut offset = *offset;
                offset += FDT_TAGSIZE; // Skip FDT_BEGIN_NODE
                offset = fdt.find_string_end(offset).expect("Fdt should be valid");
                offset = Fdt::align_tag_offset(offset);
                *self = Self::Running { fdt: *fdt, offset };
                self.next()
            }
            Self::Running { fdt, offset } => Self::next_prop(*fdt, offset),
        }
    }
}

impl<'a> FdtPropIter<'a> {
    fn next_prop(fdt: Fdt<'a>, offset: &mut usize) -> Option<FdtProperty<'a>> {
        loop {
            let token = fdt.read_token(*offset).expect("Fdt should be valid");
            match token {
                FdtToken::Prop => {
                    let len = big_endian::U32::ref_from_prefix(&fdt.data[*offset + FDT_TAGSIZE..])
                        .expect("Fdt should be valid")
                        .0
                        .get() as usize;
                    let nameoff =
                        big_endian::U32::ref_from_prefix(&fdt.data[*offset + 2 * FDT_TAGSIZE..])
                            .expect("Fdt should be valid")
                            .0
                            .get() as usize;
                    let prop_offset = *offset + 3 * FDT_TAGSIZE;
                    *offset = Fdt::align_tag_offset(prop_offset + len);
                    let name = fdt.string(nameoff).expect("Fdt should be valid");
                    let value = fdt
                        .data
                        .get(prop_offset..prop_offset + len)
                        .expect("Fdt should be valid");
                    return Some(FdtProperty { name, value });
                }
                FdtToken::Nop => *offset += FDT_TAGSIZE,
                _ => return None,
            }
        }
    }
}
*/
