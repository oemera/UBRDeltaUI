//
//  UBRDeltaContent.swift
//
//  Created by Karsten Bruns on 27/08/15.
//  Copyright © 2015 bruns.me. All rights reserved.
//

import Foundation


class UBRDeltaContent {
    
    typealias ItemUpdateHandler = (_ items: [ComparableItem], _ section: Int, _ insertIndexPaths: [Int], _ reloadIndexPaths: [Int:Int], _ deleteIndexPaths: [Int]) -> ()
    typealias ItemReorderHandler = (_ items: [ComparableItem], _ section: Int, _ reorderMap: [Int:Int]) -> ()
    typealias SectionUpdateHandler = (_ sections: [ComparableSectionItem], _ insertIndexSet: [Int], _ reloadIndexSet: [Int:Int], _ deleteIndexSet: [Int]) -> ()
    typealias SectionReorderHandler = (_ sections: [ComparableSectionItem], _ reorderMap: [Int:Int]) -> ()
    typealias StartHandler = () -> ()
    typealias CompletionHandler = () -> ()
    
    var userInterfaceUpdateTime: Double = 0.2
    var debugOutput = false
    
    // Update handler
    var itemUpdate: ItemUpdateHandler? = nil
    var itemReorder: ItemReorderHandler? = nil
    var sectionUpdate: SectionUpdateHandler? = nil
    var sectionReorder: SectionReorderHandler? = nil
    
    var start: StartHandler? = nil
    var completion: CompletionHandler? = nil
    
    // State vars for background operations
    fileprivate var isDiffing: Bool = false
    fileprivate var resultIsOutOfDate: Bool = false
    
    // State vars to throttle UI update
    fileprivate var timeLockEnabled: Bool = false
    fileprivate var lastUpdateTime: Date = Date(timeIntervalSince1970: 0)
    
    // Section data
    fileprivate var oldSections: [ComparableSectionItem]? = nil
    fileprivate var newSections: [ComparableSectionItem]? = nil
    
    
    init() {}
    
    
    func queueComparison(oldSections: [ComparableSectionItem], newSections: [ComparableSectionItem])
    {
        // Set Sections
        if self.oldSections == nil {
            // Old section should change only when a diff completes
            // and it got nilled
            self.oldSections = oldSections
        }
        
        // New section are always defined
        self.newSections = newSections
        
        // Guarding
        if isDiffing == true {
            // We declare the current result as out-of-date
            // because more recent 'newSections' are available
            self.resultIsOutOfDate = true
            return
        }
        
        diff()
    }
    
    
    fileprivate func diff()
    {
        // Guarding
        guard let oldSections = self.oldSections else { return }
        guard let newSections = self.newSections else { return }
        
        // Define State
        self.isDiffing = true
        self.resultIsOutOfDate = false

        // Do the diffing on a background thread
        let backgroundQueue = DispatchQueue.global()

        backgroundQueue.async {

            let findDuplicatedItems = self.debugOutput
            
            // Diffing Items
            var itemDiffs = [Int: ComparisonResult]()
            for (oldSectionIndex, oldSection) in oldSections.enumerated() {
                
                let newIndex = newSections.index(where: { newSection -> Bool in
                    let comparisonLevel = newSection.compareTo(oldSection)
                    return comparisonLevel.isSame
                })
                
                if let newIndex = newIndex {
                    // Diffing
                    let oldItems = oldSection.subitems
                    let newItems = newSections[newIndex].subitems
                    let itemDiff = UBRDelta.diff(old: oldItems, new: newItems, findDuplicatedItems: findDuplicatedItems)
                    itemDiffs[oldSectionIndex] = itemDiff
                    
                    if findDuplicatedItems {
                        if let duplicatedIndexes = itemDiff.duplicatedIndexes , duplicatedIndexes.count > 0 {
                            print("\n")
                            print("WARNING: Duplicated items detected. App will probably crash.")
                            print("Dublicated indexes:", duplicatedIndexes)
                            print("Dublicated items:", duplicatedIndexes.map({ newItems[$0] }))
                            print("\n")
                        }
                    }
                }
                
            }
            
            // Satisfy argument requirements of UBRDelta.diff()
            let oldSectionAsItems = oldSections.map({ $0 as ComparableItem })
            let newSectionsAsItems = newSections.map({ $0 as ComparableItem })
            
            // Diffing sections
            let sectionDiff = UBRDelta.diff(old: oldSectionAsItems, new: newSectionsAsItems, findDuplicatedItems: findDuplicatedItems)
            
            if findDuplicatedItems {
                if let duplicatedIndexes = sectionDiff.duplicatedIndexes , duplicatedIndexes.count > 0 {
                    print("\n")
                    print("WARNING: Duplicated section items detected. App will probably crash.")
                    print("Dublicated indexes:", duplicatedIndexes)
                    print("Dublicated section items:", duplicatedIndexes.map({ newSections[$0] }))
                    print("\n")
                }
            }

            // Diffing is done - doing UI updates on the main thread
            let mainQueue = DispatchQueue.main
            mainQueue.async {
                
                // Guardings
                if self.resultIsOutOfDate == true {
                    // In the meantime 'newResults' came in, this means
                    // a new diff() and we are stopping the update
                    self.diff()
                    return
                }
                
                if self.timeLockEnabled == true {
                    // There is already a future diff() scheduled
                    // we are stopping here
                    return
                }
                
                let updateAllowedIn = self.lastUpdateTime.timeIntervalSinceNow + self.userInterfaceUpdateTime
                if  updateAllowedIn > 0 {
                    // updateAllowedIn > 0 means the allowed update time is in the future
                    // so we schedule a new diff() for this point in time
                    self.timeLockEnabled = true
                    UBRDeltaContent.executeDelayed(updateAllowedIn) {
                        self.timeLockEnabled = false
                        self.diff()
                    }
                    return
                }
                
                // Calling the handler functions
                self.start?()
                
                // Item update for the old section order, because the sections
                // are not moved yet
                for (oldSectionIndex, itemDiff) in itemDiffs.sorted(by: { $0.0 < $1.0 }) {
                    
                    // Call item handler functions
                    self.itemUpdate?(
                        itemDiff.unmovedItems,
                        oldSectionIndex,
                        itemDiff.insertionIndexes,
                        itemDiff.reloadIndexMap,
                        itemDiff.deletionIndexes
                    )
                    self.itemReorder?(itemDiff.newItems, oldSectionIndex, itemDiff.moveIndexMap)
                    
                }
                
                // Change type from ComparableItem to ComparableSectionItem.
                // Since this is expected to succeed a force unwrap is justified
                let updateItems = sectionDiff.unmovedItems.map({ $0 as! ComparableSectionItem })
                let reorderItems = sectionDiff.newItems.map({ $0 as! ComparableSectionItem })
                
                // Call section handler functions
                self.sectionUpdate?(updateItems, sectionDiff.insertionIndexes, sectionDiff.reloadIndexMap, sectionDiff.deletionIndexes)
                self.sectionReorder?(reorderItems, sectionDiff.moveIndexMap)
                
                // Call completion block
                self.completion?()
                
                // Reset state
                self.lastUpdateTime = Date()
                self.oldSections = nil
                self.newSections = nil
                self.isDiffing = false
            }
            
        }
        
    }
    
    
    static fileprivate func executeDelayed(_ time: Int, action: @escaping () -> ())
    {
        self.executeDelayed(Double(time), action: action)
    }
    
    
    static fileprivate func executeDelayed(_ time: Double, action: @escaping () -> ())
    {
        if time == 0 {
            action()
            return
        }
        
        let nanoSeconds: Int64 = Int64(Double(NSEC_PER_SEC) * time);
        let when = DispatchTime.now() + Double(nanoSeconds) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: when, execute: {
            action()
        })
    }
    
}
