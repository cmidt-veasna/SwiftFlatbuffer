//
//  writer.swift
//  FlatbufferSwift
//
//  Created by Veasna Sreng on 2/25/17.
//
//

import Foundation

enum DataError: Error {
    case IndexOutOfBound
}

extension Data {
    
    public mutating func expandFromTail(by: Int) {
        self.append(Data(count: by))
    }
    
    public mutating func expandFromHead(by: Int) {
        var data = Data(count: by)
        data.append(self)
        self = data
    }
    
    // checking index to prevent crash maybe not really useful as we might reprevent it with
    // 0 value of the offset this mean default object, empty string or 0 value will return
    // in this case, check index might be useless
    private func ensureIndexOrRangeIsAvailable(at: Int, by: Int) throws {
        if at >= self.count || (at + by) >= self.count {
            throw DataError.IndexOutOfBound
        }
    }
    
    // we can use generic type to input byte into Data, however it a bit slower than plain function
    //
    public mutating func putBool(at: Int, with: Bool) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 0)
        self[at] = with ? UInt8(1) : UInt8(0)
    }
    
    public mutating func putByte(at: Int, with: Int8) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 0)
        self[at] = UInt8(with)
    }
    
    public mutating func putUnsignedByte(at: Int, with: UInt8) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 0)
        self[at] = with
    }
    
    public mutating func putShort(at: Int, with: Int16) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 1)
        self[at] = UInt8(truncatingBitPattern: with)
        self[at + 1] = UInt8(truncatingBitPattern: with>>8)
    }
    
    public mutating func putUnsignedShort(at: Int, with: UInt16) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 1)
        self[at] = UInt8(truncatingBitPattern: with)
        self[at + 1] = UInt8(truncatingBitPattern: with>>8)
    }
    
    public mutating func putInt(at: Int, with: Int32) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 3)
        self[at] = UInt8(truncatingBitPattern: with)
        self[at + 1] = UInt8(truncatingBitPattern: with>>8)
        self[at + 2] = UInt8(truncatingBitPattern: with>>16)
        self[at + 3] = UInt8(truncatingBitPattern: with>>24)
    }
    
    public mutating func putUnsignedInt(at: Int, with: UInt32) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 3)
        self[at] = UInt8(truncatingBitPattern: with)
        self[at + 1] = UInt8(truncatingBitPattern: with>>8)
        self[at + 2] = UInt8(truncatingBitPattern: with>>16)
        self[at + 3] = UInt8(truncatingBitPattern: with>>24)
    }
    
    public mutating func putLong(at: Int, with: Int64) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 7)
        self[at] = UInt8(truncatingBitPattern: with)
        self[at + 1] = UInt8(truncatingBitPattern: with>>8)
        self[at + 2] = UInt8(truncatingBitPattern: with>>16)
        self[at + 3] = UInt8(truncatingBitPattern: with>>24)
        self[at + 4] = UInt8(truncatingBitPattern: with>>32)
        self[at + 5] = UInt8(truncatingBitPattern: with>>40)
        self[at + 6] = UInt8(truncatingBitPattern: with>>48)
        self[at + 7] = UInt8(truncatingBitPattern: with>>56)
    }
    
    public mutating func putUnsignedLong(at: Int, with: UInt64) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 7)
        self[at] = UInt8(truncatingBitPattern: with)
        self[at + 1] = UInt8(truncatingBitPattern: with>>8)
        self[at + 2] = UInt8(truncatingBitPattern: with>>16)
        self[at + 3] = UInt8(truncatingBitPattern: with>>24)
        self[at + 4] = UInt8(truncatingBitPattern: with>>32)
        self[at + 5] = UInt8(truncatingBitPattern: with>>40)
        self[at + 6] = UInt8(truncatingBitPattern: with>>48)
        self[at + 7] = UInt8(truncatingBitPattern: with>>56)
    }
    
    public mutating func putFloat(at: Int, with: Float) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 3)
        self[at] = UInt8(truncatingBitPattern: with.bitPattern)
        self[at + 1] = UInt8(truncatingBitPattern: with.bitPattern>>8)
        self[at + 2] = UInt8(truncatingBitPattern: with.bitPattern>>16)
        self[at + 3] = UInt8(truncatingBitPattern: with.bitPattern>>24)
    }
    
    public mutating func putDouble(at: Int, with: Double) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: 7)
        self[at] = UInt8(truncatingBitPattern: with.bitPattern)
        self[at + 1] = UInt8(truncatingBitPattern: with.bitPattern>>8)
        self[at + 2] = UInt8(truncatingBitPattern: with.bitPattern>>16)
        self[at + 3] = UInt8(truncatingBitPattern: with.bitPattern>>24)
        self[at + 4] = UInt8(truncatingBitPattern: with.bitPattern>>32)
        self[at + 5] = UInt8(truncatingBitPattern: with.bitPattern>>40)
        self[at + 6] = UInt8(truncatingBitPattern: with.bitPattern>>48)
        self[at + 7] = UInt8(truncatingBitPattern: with.bitPattern>>56)
    }
    
    public mutating func putByteArray(at: Int, with: [UInt8]) throws {
        try ensureIndexOrRangeIsAvailable(at: at, by: with.count - 1)
        for i in 0..<with.count {
            self[at + i] = with[i]
        }
    }

}
