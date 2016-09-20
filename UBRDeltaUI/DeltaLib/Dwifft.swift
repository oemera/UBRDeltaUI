//
//  LCS.swift
//  Dwifft
//
//  Created by Jack Flintermann on 3/14/15.
//  Copyright (c) 2015 jflinter. All rights reserved.
//

/*
The MIT License (MIT)

Copyright (c) 2015 Jack Flintermann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

internal struct Diff<T> {
    internal let results: [DiffStep<T>]
}

internal func +<T> (left: Diff<T>, right: DiffStep<T>) -> Diff<T> {
    return Diff<T>(results: left.results + [right])
}

/// These get returned from calls to DiffArray.diff(). They represent insertions or deletions that need to happen to transform array a into array b.
internal enum DiffStep<T> : CustomDebugStringConvertible {
    case insert(Int, T)
    case delete(Int, T)
    var debugDescription: String {
        switch(self) {
        case .insert(let i, let j):
            return "+\(j)@\(i)"
        case .delete(let i, let j):
            return "-\(j)@\(i)"
        }
    }
}

internal struct DiffArray<Element: Equatable> {
    
    /// Returns the sequence of ArrayDiffResults required to transform one array into another.
    static func diff(_ arrayA: [Element], _ arrayB: [Element]) -> Diff<Element> {
        let table = DiffArray.buildTable(arrayA, arrayB, arrayA.count, arrayB.count)
        return DiffArray.diffFromIndices(table, arrayA, arrayB, arrayA.count, arrayB.count)
    }
    
    /// Walks back through the generated table to generate the diff.
    fileprivate static func diffFromIndices(_ table: [[Int]], _ x: [Element], _ y: [Element], _ i: Int, _ j: Int) -> Diff<Element> {
        if i == 0 && j == 0 {
            return Diff<Element>(results: [])
        } else if i == 0 {
            return diffFromIndices(table, x, y, i, j-1) + DiffStep.insert(j-1, y[j-1])
        } else if j == 0 {
            return diffFromIndices(table, x, y, i - 1, j) + DiffStep.delete(i-1, x[i-1])
        } else if table[i][j] == table[i][j-1] {
            return diffFromIndices(table, x, y, i, j-1) + DiffStep.insert(j-1, y[j-1])
        } else if table[i][j] == table[i-1][j] {
            return diffFromIndices(table, x, y, i - 1, j) + DiffStep.delete(i-1, x[i-1])
        } else {
            return diffFromIndices(table, x, y, i-1, j-1)
        }
    }
    
    fileprivate static func buildTable(_ x: [Element], _ y: [Element], _ n: Int, _ m: Int) -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n {
            for j in 0...m {
                if (i == 0 || j == 0) {
                    table[i][j] = 0
                }
                else if x[i-1] == y[j-1] {
                    table[i][j] = table[i-1][j-1] + 1
                } else {
                    table[i][j] = max(table[i-1][j], table[i][j-1])
                }
            }
        }
        return table
    }
}
