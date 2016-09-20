//
//  UITableViewCell+Protocols.swift
//  CompareApp
//
//  Created by Karsten Bruns on 29/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import UIKit



public typealias SelectionHandler = () -> ()


public protocol DeltaTableViewItem : ComparableItem {
    var id: String { get }
    var reuseIdentifier: String { get }
}


public protocol DeltaTableViewHeaderFooterItem : ComparableItem {
    var id: String { get }
    var reuseIdentifier: String { get }
}


public protocol UpdateableTableViewCell : class {
    func updateCellWithItem(_ item: ComparableItem, animated: Bool)
}


public protocol UpdateableTableViewHeaderFooterView : class {
    func updateViewWithItem(_ item: ComparableItem, animated: Bool, type: HeaderFooterType)
}


public enum HeaderFooterType {
    case header, footer
}


public protocol SelectableTableViewItem {
    var selectionHandler: SelectionHandler? { get }
}


/// A helper function to avoid reference cycles in action handler
public func weakActionHandler<Target: AnyObject, Result>(_ target: Target, handler: @escaping (Target) -> ((Result) -> Void)) -> ((Result) -> Void) {
    return { [weak target] result in
        guard let t = target else { return }
        handler(t)(result)
    }
}


/// A helper function to avoid reference cycles in action handler
public func weakActionHandler<Target: AnyObject>(_ target: Target, handler: @escaping (Target) -> (() -> Void)) -> (() -> Void) {
    return { [weak target] in
        guard let t = target else { return }
        handler(t)()
    }
}


/// A helper function to avoid reference cycles in action handler.
/// This version allows to provide extra context
public func weakActionHandler<Target: AnyObject, Context, Result>(_ target: Target, handler: @escaping (Target) -> ((Result, Context) -> Void), context: Context) -> ((Result) -> Void) {
    return { [weak target] result in
        guard let t = target else { return }
        handler(t)(result, context)
    }
}


/**
 A helper function to avoid reference cycles in action handler.
 This version allows to provide extra context, but does not take a value
 */
public func weakActionHandler<Target: AnyObject, Context>(_ target: Target, handler: @escaping (Target) -> ((Context) -> Void), context: Context) -> (() -> Void) {
    return { [weak target] in
        guard let t = target else { return }
        handler(t)(context)
    }
}
