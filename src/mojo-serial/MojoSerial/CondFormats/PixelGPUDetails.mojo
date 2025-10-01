from sys import sizeof

from MojoSerial.MojoBridge.DTypes import UChar


@nonmaterializable(NoneType)
struct PixelGPUDetails:
    alias layerStartBit: UInt32 = 20
    alias ladderStartBit: UInt32 = 12
    alias moduleStartBit: UInt32 = 2

    alias panelStartBit: UInt32 = 10
    alias diskStartBit: UInt32 = 18
    alias bladeStartBit: UInt32 = 12

    alias layerMask: UInt32 = 0xF
    alias ladderMask: UInt32 = 0xFF
    alias moduleMask: UInt32 = 0x3FF
    alias panelMask: UInt32 = 0x3
    alias diskMask: UInt32 = 0xF
    alias bladeMask: UInt32 = 0x3F

    alias LINK_bits: UInt32 = 6
    alias ROC_bits: UInt32 = 5
    alias DCOL_bits: UInt32 = 5
    alias PXID_bits: UInt32 = 8
    alias ADC_bits: UInt32 = 8

    # special for layer 1
    alias LINK_bits_l1: UInt32 = 6
    alias ROC_bits_l1: UInt32 = 5
    alias COL_bits_l1: UInt32 = 6
    alias ROW_bits_l1: UInt32 = 7
    alias OMIT_ERR_bits: UInt32 = 1

    alias maxROCIndex: UInt32 = 8
    alias numRowsInRoc: UInt32 = 80
    alias numColsInRoc: UInt32 = 52

    alias MAX_WORD: UInt32 = 2000

    alias ADC_shift: UInt32 = 0
    alias PXID_shift: UInt32 = Self.ADC_shift + Self.ADC_bits
    alias DCOL_shift: UInt32 = Self.PXID_shift + Self.PXID_bits
    alias ROC_shift: UInt32 = Self.DCOL_shift + Self.DCOL_bits
    alias LINK_shift: UInt32 = Self.ROC_shift + Self.ROC_bits_l1

    # special for layer 1 ROC
    alias ROW_shift: UInt32 = Self.ADC_shift + Self.ADC_bits
    alias COL_shift: UInt32 = Self.ROW_shift + Self.ROW_bits_l1
    alias OMIT_ERR_shift: UInt32 = 20

    alias LINK_mask: UInt32 = ~(~UInt32(0) << Self.LINK_bits_l1)
    alias ROC_mask: UInt32 = ~(~UInt32(0) << Self.ROC_bits_l1)
    alias COL_mask: UInt32 = ~(~UInt32(0) << Self.COL_bits_l1)
    alias ROW_mask: UInt32 = ~(~UInt32(0) << Self.ROW_bits_l1)
    alias DCOL_mask: UInt32 = ~(~UInt32(0) << Self.DCOL_bits)
    alias PXID_mask: UInt32 = ~(~UInt32(0) << Self.PXID_bits)
    alias ADC_mask: UInt32 = ~(~UInt32(0) << Self.ADC_bits)
    alias ERROR_mask: UInt32 = ~(~UInt32(0) << Self.ROC_bits_l1)
    alias OMIT_ERR_mask: UInt32 = ~(~UInt32(0) << Self.OMIT_ERR_bits)

    # Maximum fed for phase1 is 150 but not all of them are filled
    # Update the number FED based on maximum fed found in the cabling map
    alias MAX_FED: UInt32 = 150
    alias MAX_LINK: UInt32 = 48  # maximum links/channels for Phase 1
    alias MAX_ROC: UInt32 = 8
    alias MAX_SIZE = Self.MAX_FED * Self.MAX_LINK * Self.MAX_ROC
    alias MAX_SIZE_BYTE_BOOL = Self.MAX_SIZE * sizeof[UChar]()
    # number of words for all the FEDs
    alias MAX_FED_WORDS = Self.MAX_FED * Self.MAX_WORD
