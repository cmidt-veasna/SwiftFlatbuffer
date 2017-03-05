//
//  table.swift
//  FlatbufferSwift
//
//  Created by Veasna Sreng on 2/14/17.
//  Copyright © 2017 Veasna Sreng. All rights reserved.
//

import Foundation

public protocol Vector {
    
    func getTable<T: Struct>(at: Int, withOffset: Int) -> T
    
    func getTable<T: Struct>(at: Int, withOffset: Int, withPrevious: T) -> T
    
}

public class VectorTableHelper<T: Vector, R: Struct> {
    
    private var object: T
    private var offset: Int
    
    init(object: T, offset: Int) {
        self.object = object
        self.offset = offset
    }
    
    subscript(at: Int) -> R {
        return object.getTable(at: at, withOffset: self.offset)
    }
    
    subscript(at: Int, previous: R) -> R {
        return self.object.getTable(at: at, withOffset: self.offset, withPrevious: previous)
    }

}

public class VectorIntegerHelper<T: Table, R: Integer> {
    
    private var object: T
    private var offset: Int
    private var mutatingClosure: (T, Int, R) -> Bool
    
    init(object: T, offset: Int) {
        self.object = object
        self.offset = offset
        self.mutatingClosure = {_ in return false}
    }
    
    init(object: T, offset: Int, _ mutatingClosure: @escaping (T, Int, R) -> Bool) {
        self.object = object
        self.offset = offset
        self.mutatingClosure = mutatingClosure
    }
    
    subscript(at: Int) -> R {
        get {
            return self.object.getScalar(at: at, withOffset: self.offset)
        }
        set(newValue) {
            let offset = self.object.__offset(virtualTableOffset: self.offset)
            _ = self.mutatingClosure(self.object, self.object.__vector(offset: offset) + at * MemoryLayout<R>.stride, newValue)
        }
    }
    
}

public class VectorBoolHelper<T: Table> {
    
    private var object: T
    private var offset: Int
    private var mutatingClosure: (T, Int, Bool) -> Bool
    
    init(object: T, offset: Int) {
        self.object = object
        self.offset = offset
        self.mutatingClosure = {_ in return false}
    }
    
    init(object: T, offset: Int, _ mutatingClosure: @escaping (T, Int, Bool) -> Bool) {
        self.object = object
        self.offset = offset
        self.mutatingClosure = mutatingClosure
    }
    
    subscript(at: Int) -> Bool {
        get {
            return self.object.getScalar(at: at, withOffset: self.offset) as Int8 != 0
        }
        set(newValue) {
            let offset = self.object.__offset(virtualTableOffset: self.offset)
            _ = self.mutatingClosure(self.object, self.object.__vector(offset: offset) + at, newValue)
        }
    }
    
}

public class VectorFloatingPointHelper<T: Table, R: FloatingPoint> {
    
    private var object: T
    private var offset: Int
    
    init(object: T, offset: Int) {
        self.object = object
        self.offset = offset
    }
    
    subscript(at: Int) -> R {
        return self.object.getScalar(at: at, withOffset: self.offset)
    }
    
}

public class VectorEnumHelper<T: Table, R: RawRepresentable> where R.RawValue == Int8 {
    
    private var object: T
    private var offset: Int
    
    init(object: T, offset: Int) {
        self.object = object
        self.offset = offset
    }
    
    subscript(at: Int) -> R {
        return R(rawValue: self.object.getScalar(at: at, withOffset: self.offset))!
    }
    
}

public class VectorStringHelper<T: Table> {
    
    private var object: T
    private var offset: Int
    
    init(object: T, offset: Int) {
        self.object = object
        self.offset = offset
    }
    
    subscript(at: Int) -> String {
        let offset = self.object.__offset(virtualTableOffset: self.offset)
        return offset != 0 ? self.object.__string(offset: self.object.__vector(offset: offset) + at * 4) : ""
    }
    
}

public class Table: Struct, Vector {
    
    required public init() {}
    
    open override func __assign(at: Int, withData: inout Data) -> Table {
        return super.__assign(at: at, withData: &withData) as! Table
    }
    
    public func getScalar<R: Integer>(at: Int, withOffset: Int) -> R {
        let offset = __offset(virtualTableOffset: withOffset)
        return offset == 0 ? 0 : (data!.getInteger(at: __vector(offset: offset) + at * MemoryLayout<R>.stride) as R)
    }
    
    public func getScalar<R: FloatingPoint>(at: Int, withOffset: Int) -> R {
        let offset = __offset(virtualTableOffset: withOffset)
        return offset == 0 ? 0 : (data!.getFloatingPoint(at: __vector(offset: offset) + at * MemoryLayout<R>.stride) as R)
    }
    
    public func getTable<T: Struct>(at: Int, withOffset: Int) -> T {
        return self.getTable(at: at, withOffset: withOffset, withPrevious: T())
    }
    
    public func getTable<T: Struct>(at: Int, withOffset: Int, withPrevious: T) -> T {
        let offset = __offset(virtualTableOffset: withOffset)
        return offset == 0 ? T() :
            (T.self is Table.Type ?
                withPrevious.__assign(at: __indirect(offset: __vector(offset: offset) + (at * 4)), withData: &data!) as! T :
                withPrevious.__assign(at: __vector(offset: offset) + (at * 4), withData: &data!) as! T)
    }
    
    open override func getStruct<T: Struct>(byOffset: Int, withPrevious: T) -> T {
        let offset = __offset(virtualTableOffset: byOffset)
        return offset == 0 ? T() : withPrevious.__assign(at:
                T.self == Struct.self ? offset + position : __indirect(offset: offset + position),
                                                   withData: &data!) as! T
    }
    
    open func compareKey(of: UOffsetT, with: UOffsetT, by data: inout Data) -> Bool {
        return true
    }
    
}

extension Table {
    
    open func __indirect(offset: Int) -> Int {
        return offset + (data?.getOffset(at: offset))!
    }
    
    open static func __indirect(offset: Int, data: inout Data) -> Int {
        return offset + data.getOffset(at: offset)
    }
    
    open func __string(offset: Int) -> String {
        var newOffset = offset + (data?.getOffset(at: offset))!
        let stringLength = data?.getOffset(at: newOffset)
        newOffset += Constants.SizeInt32
        return String(bytes: (data!.getArray(at: newOffset, count: stringLength!, withType: UInt8.self))!, encoding: String.Encoding.utf8)!
    }
    
    open func __bool(offset: Int, value: Bool = false) -> Bool {
        let newOffset = __offset(virtualTableOffset: offset)
        return newOffset != 0 ? 0 != Int((data?.getByte(at: newOffset + position))!) : value
    }
    
    open func __vectorLength(offset: Int) -> Int {
        var newOffset = offset + position
        newOffset = newOffset + (data?.getOffset(at: newOffset))!
        return data!.getOffset(at: newOffset)
    }

    open func __vector(offset: Int) -> Int {
        let newOffset = offset + position
        return newOffset + data!.getOffset(at: newOffset) + Constants.SizeInt32
    }

    open func __union(table: Table, offset: Int) -> Table {
        let newOffset = offset + position
        table.position = newOffset + (data?.getOffset(at: newOffset))!
        table.data = data
        return table
    }

    open static func __has_identifier(withData: inout Data, at: Int, ident: String) -> Bool {
        if (ident.characters.count != Constants.FileIdentifierLength) {
            return false
        }
        for i in 0...(Constants.FileIdentifierLength - 1) {
            let ch = withData.getUnsignedByte(at: at + Constants.SizeInt32 + i)
            if (ident[i] != Character(UnicodeScalar(ch)) ) {
                return false
            }
        }
        return true
    }
    
}
