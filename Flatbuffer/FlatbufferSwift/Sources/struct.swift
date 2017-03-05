//
//  struct.swift
//  FlatbufferSwift
//
//  Created by Veasna Sreng on 2/14/17.
//  Copyright © 2017 Veasna Sreng. All rights reserved.
//

import Foundation

public class Struct {

    var position: Int = 0
    var data: Data?
    
    required public init() {}
    
    open func __init(at: Int, withData: inout Data) {
        self.position = at
        self.data = withData
    }
    
    open func __assign(at: Int, withData: inout Data) -> Struct {
        self.__init(at: at, withData: &withData)
        return self
    }
    
    open func __offset(virtualTableOffset: Int) -> Int {
        if data != nil, let val = (data?.getOffset(at: position)) {
            let vtable = position - val
            let result = virtualTableOffset < data!.getVirtualTaleOffset(at: vtable) ? data!.getVirtualTaleOffset(at: vtable + virtualTableOffset) : 0
            return result
        }
        return 0
    }
    
    open static func __offset(virtualTableOffset: Int, offset: Int, data: inout Data) -> Int {
        let vtable = data.count - offset;
        return data.getVirtualTaleOffset(at: vtable + virtualTableOffset - data.getVirtualTaleOffset(at: vtable)) + vtable
    }
    
    open func getStruct<T: Struct>(byOffset: Int) -> T {
        return getStruct(byOffset: byOffset, withPrevious: T())
    }
    
    open func getStruct<T: Struct>(byOffset: Int, withPrevious: T) -> T {
        return withPrevious.__assign(at: position + byOffset, withData: &data!) as! T
    }
    
}
