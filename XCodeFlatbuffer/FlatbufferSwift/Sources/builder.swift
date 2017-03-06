//
//  builder.swift
//  FlatbufferSwift
//
//  Created by Veasna Sreng on 2/15/17.
//
//

import Foundation

extension Table {
    
    public static func compareString(of: Int, with: Int, by data: inout Data) -> Int {
        let firstOffset = of + Int(data.getInt(at: of))
        let secondOffset = with + Int(data.getInt(at: with))
        let firstSize = data.getInt(at: firstOffset)
        let secondSize = data.getInt(at: secondOffset)
        let firstStartPosition = firstOffset + Constants.SizeInt32
        let secondStartPosition = secondOffset + Constants.SizeInt32
        let size = min(firstSize, secondSize)
        for i in 0..<Data.Index(size) {
            if data[i + firstStartPosition] != data[i + secondStartPosition] {
                let a = Int(data[i + firstStartPosition])
                let b = Int(data[i + secondStartPosition])
                return a - b
            }
        }
        return firstSize - secondSize
    }
    
    public static func compareString(of: Int, with key: [UInt8], by data: inout Data) -> Int {
        let firstOffset = of + Int(data.getInt(at: of))
        let firstSize = data.getInt(at: firstOffset)
        let secondSize = key.count
        let firstStartPosition = firstOffset + Constants.SizeInt32
        let size = min(firstSize, Int32(secondSize))
        for i in 0..<Data.Index(size) {
            if data[i + firstStartPosition] != key[i] {
                return Int(data[i + firstStartPosition]) - Int(key[i])
            }
        }
        return Int(firstSize - secondSize)
    }
    
    open func sortTable(_ data: inout Data, listOffset: inout [UOffsetT]) {
        listOffset.sort { (first, second) -> Bool in
            return compareKey(of: first, with: second, by: &data)
        }
    }
    
}

enum BuilderError: Error {
    //
    case InvalidConstructionOrder
    //
    case BuilderHasnotFinishYet
    //
    case UnreachableOffset
    //
    case InlineDataOutsideObject
    //
    case InvalidFileIdentifier
}

// A SOffsetT stores a signed offset into arbitrary data.
public typealias SOffsetT = Int32
// A UOffsetT stores an unsigned offset into vector data.
public typealias UOffsetT = UInt32
// A VOffsetT stores an unsigned offset in a vtable.
public typealias VOffsetT = UInt16

public final class Builder {

    public static let VirtualTableMetadataFields = 2
    
    private var data:           Data
    private var minalign:       Int
    private var vtable:         [UOffsetT] = []
    private var objectEnd:      UOffsetT = 0
    private var vtables:        [UOffsetT]
    private var head:           UOffsetT
    private var nested:         Bool = false
    private var finished:       Bool = false
    private var forceDefaults:  Bool = false
    
    public init(capacity: Int) {
        var initialSize = capacity
        if initialSize <= 0 {
            initialSize = 0
        }
        data = Data(count: capacity)
        head = UOffsetT(initialSize)
        minalign = 1
        vtables = [UOffsetT](repeating: 0, count: 0)
        vtables.reserveCapacity(16)
    }
    
    public init(data: Data) {
        self.data = data
        self.data.removeAll()
        head = UOffsetT(data.count)
        minalign = 1
        vtables = [UOffsetT](repeating: 0, count: 16)
    }
    
    // reset buffer data to 0 and all state. This useful when you want to reuse the Data
    // to rebuild flatbuffer binary over again
    public func reset(keepingCapacity: Bool = false) {
        // keep byte allocated
        data.removeAll(keepingCapacity: keepingCapacity)
        data.resetBytes(in: 0..<data.count)
        vtable.removeAll()
        vtables.removeAll()
        head = UOffsetT(data.count)
        minalign = 1
        nested = false
        finished = false
    }
    
    // force the default value to be written to buffer
    public func forceDefault(_ forced: Bool) {
        self.forceDefaults = forced
    }
    
    public func startObject(numberOfFields: Int) throws {
        try assertNotNested()
        nested = true;
        
        if vtable.count < numberOfFields {
            vtable = [UOffsetT](repeating: 0, count: numberOfFields)
        } else {
            // remove from all element start from numberOfFields
            vtable.removeSubrange(numberOfFields - 1..<vtable.count)
            for index in 0..<vtable.count {
                vtable[index] = 0
            }
        }
        
        objectEnd = offset()
        minalign = 1
    }
    
    
    public func endObject() throws -> UOffsetT {
        try assertNested()
        let uOffset =  try self.writeVirtualTable()
        nested = false
        return uOffset
    }

    public func putBool(offset: Int, with: Bool, byDefault: Bool) throws {
        let val = Int8(with ? 1 : 0)
        let def = Int8(byDefault ? 1 : 0)
        try putByte(offset: offset, with: val, byDefault: def)
    }
    
    public func putBool(with: Bool) throws {
        let val = Int8(with ? 1 : 0)
        try putByte(with: val)
    }
    
    // byte method
    
    public func putByte(offset: Int, with: Int8, byDefault: Int8) throws {
        if self.forceDefaults || with != byDefault {
            try self.putByte(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putByte(with: Int8) throws {
        try prepare(size: Constants.SizeInt8, additionalBytes: 0)
        try self.putByteWithoutPrepare(with: with)
    }
    
    public func putByteWithoutPrepare(with: Int8) throws {
        self.head -= UOffsetT(Constants.SizeInt8)
        try self.data.putByte(at: Int(self.head), with: with)
    }
    
    // unsigned byte method
    
    public func putUnsignedByte(offset: Int, with: UInt8, byDefault: UInt8) throws {
        if self.forceDefaults || with != byDefault {
            try putUnsignedByte(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putUnsignedByte(with: UInt8) throws {
        try prepare(size: Constants.SizeUint8, additionalBytes: 0)
        try putUnsignedByteWithoutPrepare(with: with)
    }
    
    public func putUnsignedByteWithoutPrepare(with: UInt8) throws {
        self.head -= UOffsetT(Constants.SizeUint8)
        try self.data.putUnsignedByte(at: Int(self.head), with: with)
    }

    // short method
    
    public func putShort(offset: Int, with: Int16, byDefault: Int16) throws {
        if self.forceDefaults || with != byDefault {
            try self.putShort(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putShort(with: Int16) throws {
        try prepare(size: Constants.SizeInt16, additionalBytes: 0)
        try self.putShortWithoutPrepare(with: with)
    }
    
    public func putShortWithoutPrepare(with: Int16) throws {
        self.head -= UOffsetT(Constants.SizeInt16)
        try self.data.putShort(at: Int(self.head), with: with)
    }
    
    // unsigned short method
    
    public func putUnsignedShort(offset: Int, with: UInt16, byDefault: UInt16) throws {
        if self.forceDefaults || with != byDefault {
            try self.putUnsignedShort(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putUnsignedShort(with: UInt16) throws {
        try prepare(size: Constants.SizeUint16, additionalBytes: 0)
        try self.putUnsignedShortWithoutPrepare(with: with)
    }
    
    public func putUnsignedShortWithoutPrepare(with: UInt16) throws {
        self.head -= UOffsetT(Constants.SizeUint16)
        try self.data.putUnsignedShort(at: Int(self.head), with: with)
    }
    
    // int method
    
    public func putInt(offset: Int, with: Int32, byDefault: Int32) throws {
        if self.forceDefaults || with != byDefault {
            try self.putInt(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putInt(with: Int32) throws {
        try prepare(size: Constants.SizeInt32, additionalBytes: 0)
        try self.putIntWithoutPrepare(with: with)
    }
    
    public func putIntWithoutPrepare(with: Int32) throws {
        self.head -= UOffsetT(Constants.SizeInt32)
        try self.data.putInt(at: Int(self.head), with: with)
    }
    
    // unsigned int method
    
    public func putUnsignedInt(offset: Int, with: UInt32, byDefault: UInt32) throws {
        if self.forceDefaults || with != byDefault {
            try self.putUnsignedInt(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putUnsignedInt(with: UInt32) throws {
        try prepare(size: Constants.SizeUint32, additionalBytes: 0)
        try self.putUnsignedIntWithoutPrepare(with: with)
    }
    
    public func putUnsignedIntWithoutPrepare(with: UInt32) throws {
        self.head -= UOffsetT(Constants.SizeUint32)
        try self.data.putUnsignedInt(at: Int(self.head), with: with)
    }
    
    // long method
    
    public func putLong(offset: Int, with: Int64, byDefault: Int64) throws {
        if self.forceDefaults || with != byDefault {
            try self.putLong(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putLong(with: Int64) throws {
        try prepare(size: Constants.SizeInt64, additionalBytes: 0)
        try self.putLongWithoutPrepare(with: with)
    }
    
    public func putLongWithoutPrepare(with: Int64) throws {
        self.head -= UOffsetT(Constants.SizeInt64)
        try self.data.putLong(at: Int(self.head), with: with)
    }
    
    // usigned long method
    
    public func putUnsignedLong(offset: Int, with: UInt64, byDefault: UInt64) throws {
        if self.forceDefaults || with != byDefault {
            try self.putUnsignedLong(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putUnsignedLong(with: UInt64) throws {
        try prepare(size: Constants.SizeUint64, additionalBytes: 0)
        try self.putUnsignedLongWithoutPrepare(with: with)
    }
    
    public func putUnsignedLongWithoutPrepare(with: UInt64) throws {
        self.head -= UOffsetT(Constants.SizeUint64)
        try self.data.putUnsignedLong(at: Int(self.head), with: with)
    }
    
    // floating point method
    
    public func putFloat(offset: Int, with: Float, byDefault: Float) throws {
        if self.forceDefaults || with != byDefault {
            try self.putFloat(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putFloat(with: Float) throws {
        try prepare(size: Constants.SizeFloat32, additionalBytes: 0)
        try self.putFloatWithoutPrepare(with: with)
    }
    
    public func putFloatWithoutPrepare(with: Float) throws {
        self.head -= UOffsetT(Constants.SizeFloat32)
        try self.data.putFloat(at: Int(self.head), with: with)
    }
    
    // double
    
    public func putDouble(offset: Int, with: Double, byDefault: Double) throws {
        if self.forceDefaults || with != byDefault {
            try self.putDouble(with: with)
            self.vtable[offset] = self.offset()
        }
    }
    
    public func putDouble(with: Double) throws {
        try prepare(size: Constants.SizeFloat64, additionalBytes: 0)
        try self.putDoubleWithoutPrepare(with: with)
    }
    
    public func putDoubleWithoutPrepare(with: Double) throws {
        self.head -= UOffsetT(Constants.SizeFloat64)
        try self.data.putDouble(at: Int(self.head), with: with)
    }
    
    // object, struct & vector method
    
    public func startVector(withElementSize: Int, count: Int, alignment: Int) throws -> UOffsetT {
        try assertNotNested()
        self.nested = true
        let additionalByte = withElementSize * count
        try self.prepare(size: Constants.SizeInt32, additionalBytes: additionalByte)
        try self.prepare(size: alignment, additionalBytes: additionalByte)
        return self.offset()
    }
    
    public func createVectorOfTables(offsets: inout [UOffsetT]) throws -> UOffsetT {
        try assertNotNested()
        _ = try startVector(withElementSize: Constants.SizeInt32, count: offsets.count, alignment: Constants.SizeInt32)
        for i in (0..<offsets.count).reversed() {
            try putUnsignedTableOffset(offset: offsets[i])
        }
        return try endVector(vectorNumElems: offsets.count)
    }
    
    public func createSortedVectorOfTable<T: Table>(offsets: inout [UOffsetT], table: T) throws -> UOffsetT {
        table.sortTable(&self.data, listOffset: &offsets)
        return try createVectorOfTables(offsets: &offsets)
    }
    
    public func createString(with: String) throws -> UOffsetT {
        try assertNotNested()
        self.nested = true
        let array: [UInt8] = Array(with.utf8)
        try self.prepare(size: Constants.SizeUOffsetT, additionalBytes: (array.count + 1) * Constants.SizeByte)
        //
        self.head -= UOffsetT(Constants.SizeByte)
        try self.data.putByte(at: Int(self.head), with: 0)
        //
        self.head -= UOffsetT(array.count)
        try self.data.putByteArray(at: Int(self.head), with: array)
        
        return try endVector(vectorNumElems: array.count)
    }
    
    public func createByteVector(with: [UInt8]) throws -> UOffsetT {
        try assertNotNested()
        self.nested = true
        try prepare(size: Constants.SizeUOffsetT, additionalBytes: (with.count + 1) * Constants.SizeByte)
        self.head -= UOffsetT(with.count)
        try self.data.putByteArray(at: Int(self.head), with: with)
        return try self.endVector(vectorNumElems: with.count)
    }
  
    public func endVector(vectorNumElems: Int) throws -> UOffsetT {
        try assertNested()
        // we already made space for this, so write without PrependUint32
        self.head -= UOffsetT(Constants.SizeUOffsetT)
        try self.data.putUnsignedInt(at: Int(self.head), with: UInt32(vectorNumElems))
        self.nested = false
        return self.offset()
    }
    
    public func putStruct(virtualTable index: Int, offset: UOffsetT, defaultOffset: UOffsetT) throws {
        if offset != defaultOffset {
            try assertNested()
            if offset != self.offset() {
                throw BuilderError.InlineDataOutsideObject
            }
            self.vtable[Int(index)] = self.offset()
        }
    }
    
    public func putOffset(virtualTable index: Int, offset: UOffsetT, defaultOffset: UOffsetT) throws {
        if self.forceDefaults || offset != defaultOffset {
            try self.putUnsignedTableOffset(offset: offset)
            self.vtable[index] = self.offset()
        }
    }
    
    //
    
    public func writeVirtualTable() throws -> UOffsetT {
        try putSignedTableOffset(offset: SOffsetT(0))
        
        let objectOffset = self.offset()
        var existingVTable = UOffsetT(0)
        
        for index in (0..<vtables.count).reversed() {
            let vt2Offset = self.vtables[index]
            let vt2Start = self.data.count - Int(vt2Offset)
            let vt2Len = VOffsetT(self.data.getUsignedShort(at: vt2Start))
            
            let metadata = Builder.VirtualTableMetadataFields * Constants.SizeVOffsetT
            let vt2End = vt2Start + Int(vt2Len)
            let vt2 = self.data.subdata(in: Data.Index(vt2Start + metadata)..<Data.Index(vt2End + 1))
            if vtableEqual(vtable: self.vtable, objStart: objectOffset, vt2: vt2) {
                existingVTable = vt2Offset
                break
            }
        }
        
        if existingVTable == 0 {
            
            for i in (0..<vtable.count).reversed() {
                var off: UOffsetT = 0
                if self.vtable[i] != 0 {
                    off = objectOffset - self.vtable[i]
                }
                try self.putVirtualTableOffset(offset: VOffsetT(truncatingBitPattern: off))
            }

            let objectSize = objectOffset - self.objectEnd
            try self.putVirtualTableOffset(offset: VOffsetT(truncatingBitPattern: objectSize))
            
            // Second, store the vtable bytesize:
            let vBytes = (self.vtable.count + Builder.VirtualTableMetadataFields) * Constants.SizeVOffsetT
            try self.putVirtualTableOffset(offset: VOffsetT(truncatingBitPattern: vBytes))
            // Next, write the offset to the new vtable in the
            // already-allocated SOffsetT at the beginning of this object:
            let objectStart = SOffsetT(self.data.count) - SOffsetT(objectOffset)
            try self.data.putInt(at: Int(objectStart), with: SOffsetT(self.offset()) - SOffsetT(objectOffset))
            // Finally, store this vtable in memory for future
            // deduplication:
            self.vtables.append(self.offset())
            
        } else {
            
            let objectStart = SOffsetT(self.data.count) - SOffsetT(objectOffset)
            self.head = UOffsetT(objectStart)
            
            // Write the offset to the found vtable in the
            // already-allocated SOffsetT at the beginning of this object:
            try self.data.putInt(at: Int(self.head), with: SOffsetT(existingVTable)-SOffsetT(objectOffset))
        }
       
        self.vtable = []
        
        return objectOffset
    }
    
    public func putUnsignedTableOffset(offset: UOffsetT) throws {
        try prepare(size: Constants.SizeUOffsetT, additionalBytes: 0)
        if !(offset <= self.offset()) {
            print("offset > offset()")
            throw BuilderError.UnreachableOffset
        }
        let newOffset = self.offset() - offset + UOffsetT(Constants.SizeUOffsetT)
        self.head -= UOffsetT(Constants.SizeUOffsetT)
        try self.data.putUnsignedInt(at: Int(self.head), with: newOffset)
    }
    
    public func putVirtualTableOffset(offset: VOffsetT) throws {
        try prepare(size: Constants.SizeVOffsetT, additionalBytes: 0)
        self.head -= UOffsetT(Constants.SizeVOffsetT)
        try self.data.putUnsignedShort(at: Int(self.head), with: offset)
    }
    
    public func putSignedTableOffset(offset: SOffsetT) throws {
        try prepare(size: Constants.SizeSOffsetT, additionalBytes: 0)
        
        if !(UOffsetT(offset) <= self.offset()) {
            print("offset > offset()")
            throw BuilderError.UnreachableOffset
        }

        let newOffset = SOffsetT(self.offset()) - offset + SOffsetT(Constants.SizeSOffsetT)
        self.head -= UOffsetT(Constants.SizeSOffsetT)
        try self.data.putInt(at: Int(self.head), with: newOffset)
    }
    
    public func prepare(size: Int, additionalBytes: Int) throws {
        if size > minalign {
            minalign = size
        }
        var alignSize = (~(data.count - Int(head) +  additionalBytes)) + 1
        alignSize &= (size - 1)
        let expectedSize = alignSize + size + additionalBytes
        var oldBufSize: Int
        var growSize: Int
        while Int(head) <= expectedSize {
            oldBufSize = data.count
            if (UInt64(data.count) & UInt64(0xC0000000)) != 0 {
                throw NSError(domain: "cannot grow buffer beyond 2 gigabytes", code: 0, userInfo: nil)
            }
            // double size of buffer
            growSize = data.count == 0 ? 1 : data.count
            // expend byte from the head of data, since we build the buffer backwards
            // append expension byte
            data.expandFromHead(by: growSize)
            head += UOffsetT(data.count - oldBufSize)
        }
        paddingZero(count: alignSize)
    }
    
    public func offset() -> UOffsetT {
        return UOffsetT(data.count) - head
    }
    
    public func paddingZero(count: Int) {
        head -= UOffsetT(Constants.SizeByte) * UOffsetT(count)
        data.resetBytes(in: 0..<count)
    }
    
    public func vtableEqual(vtable: [UOffsetT], objStart: UOffsetT, vt2: Data) -> Bool {
        if vtable.count * Constants.SizeVOffsetT != vt2.count {
            return false
        }

        for i in 0..<vtable.count {
            let x = VOffsetT(self.data.getUsignedShort(at: i * Constants.SizeVOffsetT))
            if x == 0 && vtable[i] == 0 {
                continue
            }
            let y = SOffsetT(objStart) - SOffsetT(vtable[i])
            if SOffsetT(x) != y {
                return false
            }
        }
        return true
    }
    
    public func finish(by rootTableOffset: UOffsetT) throws {
        try assertNotNested()
        try self.prepare(size: self.minalign, additionalBytes: Constants.SizeUOffsetT)
        try self.putUnsignedTableOffset(offset: rootTableOffset)
        self.finished = true
    }

    public func finish(by rootTableOffset: UOffsetT, file identifier: String) throws {
        try prepare(size: minalign, additionalBytes: Constants.SizeInt32 + Constants.FileIdentifierLength)
        if identifier.characters.count != Constants.FileIdentifierLength {
            throw BuilderError.InvalidFileIdentifier
        }
        let idenBytes = [UInt8](identifier.utf8)
        for i in (0..<idenBytes.count).reversed() {
            try putUnsignedByte(with: idenBytes[i])
        }
        try finish(by: rootTableOffset)
    }
    
    public func getData() throws -> Data {
        try assertFinished()
        return self.data.subdata(in: Int(self.head)..<self.data.count)
    }
    
    private func assertNotNested() throws {
        if (nested) {
            print("Are you trying to create Table/Vector/String ? if so create them first before construct the byte buffer")
            throw BuilderError.InvalidConstructionOrder
        }
    }
    
    private func assertNested() throws {
        if !nested {
            print("Did you forget to call create Table/Struct/Vector/String ?")
            throw BuilderError.InvalidConstructionOrder
        }
    }
    
    private func assertFinished() throws {
        if !finished {
            print("Did you forget to call finish ?")
            throw BuilderError.BuilderHasnotFinishYet
        }
    }
    
}

