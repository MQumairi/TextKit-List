//
//  ViewController.swift
//  List Problems
//
//  Created by Mohammed Alqumairi on 04/07/2021.
//

import AppKit

class ViewController: NSViewController {
    //TextView from IB
    @IBOutlet var textView: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Set ViewController as textStorage delegate to receive notifications about user typing
        textView.textStorage?.delegate = self
    }
    
}

extension ViewController: NSTextStorageDelegate {
    
    //Whenever the user makes an edit, do the following
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        //Handles styling paragraphs as ordered lists, if they're prefixed with some numeral, followed by a period and space.
        handleOrderedLists(textStorage: textStorage, editedRange: editedRange)
        //Handles the tab stops issue raised in https://stackoverflow.com/questions/66714650/nstextlist-formatting
        handleTabStopsIssue(textStorage: textStorage, editedRange: editedRange)
    }
    
    /**Handles the styling of ordered lists, if the paragraph needs to be styled as an ordered list*/
    func handleOrderedLists(textStorage: NSTextStorage, editedRange: NSRange) {
        //Determine range of the edited paragraph (this is encompases the editedRange).
        let rangeOfEditedParagraph = textStorage.mutableString.paragraphRange(for: editedRange)
        //Retrieve the edited paragraph as attributed string
        let editedParagraph = textStorage.attributedSubstring(from: rangeOfEditedParagraph)
        print("\ncurrent paragraph:", editedParagraph.string)
        //Determie if the editedParagraph should be styled as an ordere list
        //True if it is prefixed with some number, followed by ". " Like in "12. hello world"
        let editedParagraphIsOrderedlist = isOrderedList(paragraph: editedParagraph)
        print("Should be styled as ordered list:", editedParagraphIsOrderedlist)
        //If it should be styled as an ordered list, style it as such
        if editedParagraphIsOrderedlist {
            styleParagraphAsList(paragraph: editedParagraph, paragraphRange: rangeOfEditedParagraph)
        }
    }
    
    /**
     ISSUE: tabStops change when user moves from nested text list, into main text list, as described in https://stackoverflow.com/questions/66714650/nstextlist-formatting
     First few tabStops are located in a position less than the default (resulting in them appearing  further to the left)
     
     (Naive) SOLUTION: If the editedParagraph contains a textList, and its first tabStop is located to the left of the default tabStop position, re-set its tabstop to default.
     */
    func handleTabStopsIssue(textStorage: NSTextStorage, editedRange: NSRange) {
        //Determine range of the edited paragraph (this is encompases the editedRange).
        let rangeOfEditedParagraph = textStorage.mutableString.paragraphRange(for: editedRange)
        //Retrieve the edited paragraph as attributed string
        let editedParagraph = textStorage.attributedSubstring(from: rangeOfEditedParagraph)
        //Enumerate the paragraphStyle attribute in the inputted paragraph NSAttributedString
        editedParagraph.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: editedParagraph.length), options: .longestEffectiveRangeNotRequired, using: {atts, subrange, _ in
            //Determine whether or not paragraph contains a textList
            guard let parStyle = atts as? NSParagraphStyle else { return }
            let parHasTextList = !parStyle.textLists.isEmpty
            
            //Retrieve the default tabStops to compare their location with inputted paragraph tabStop locations
            let defaultTabStops = NSParagraphStyle.default.tabStops
            guard let firstDefaultTabStop = defaultTabStops.first else { return }
            guard let inputParFirstTabStop = parStyle.tabStops.first else { return }
            print("firstDefaultTabStop \(firstDefaultTabStop) of location \(firstDefaultTabStop.location)")
            print("currentParTabStop \(inputParFirstTabStop) of location \(inputParFirstTabStop.location)")
            
            //If parStyle has textList, and its first tab stop is located to the left of the default tab stops...
            if (inputParFirstTabStop.location < firstDefaultTabStop.location) && parHasTextList {
                print("🔥 Resetting tabstops!")
                //Set the inputted paragraph's tab stops, to default
                let newParStyle = parStyle.mutableCopy() as! NSMutableParagraphStyle
                newParStyle.tabStops = defaultTabStops
                textView.textStorage?.addAttribute(.paragraphStyle, value: newParStyle, range: rangeOfEditedParagraph)
            }
        })
        
    }
    
    /**Determiens if paragraph is prefixed with a numeral + dot + space. If so (e.g "12. hello world"), return true. Otherwise (e.g. "hello world"), return false*/
    func isOrderedList(paragraph: NSAttributedString) -> Bool {
        //Get the numerical prefix if one exists
        let numericalPrefix = numericalPrefix(for: paragraph)
        //If numerical prefix is empty, return false (paragraph shouldn't be styled as list)
        if numericalPrefix.isEmpty { return false }
        //Otherwise determine if the two characters after the numerical prefix are dot and space (". ").
        let paragraphAsArray = Array(paragraph.string)
        if paragraphAsArray.count < numericalPrefix.count + 2 { return false }
        if paragraphAsArray[numericalPrefix.count] == Character(".") && paragraphAsArray[numericalPrefix.count + 1] == Character(" ") {
            return true
        }
        return false
    }
    
    /**Iterate over paragraph until you reach a non numeral. Output that prefix*/
    func numericalPrefix(for paragraph: NSAttributedString) -> String {
        var numeralPrefix: String = ""
        for c in paragraph.string {
            if c.isNumber {
                numeralPrefix += String(c)
            } else { return numeralPrefix }
        }
        return numeralPrefix
    }
    
    /**Given a paragraph, style it as a list*/
    func styleParagraphAsList(paragraph: NSAttributedString, paragraphRange: NSRange) {
        //Determine numericalPrefix
        let numericalPrefix = numericalPrefix(for: paragraph)
        let listNumber = Int(numericalPrefix) ?? 1
        //Determine the rest of the paragraph (the text following the numerical prefix)
        let restOfParagraph = subString(for: paragraph.string, from: numericalPrefix.count + 2)
        //Build a new paragraph comprised of a tab + numericalPrefix + tab + restOfParagraph
        let newParagraph = "\t" + numericalPrefix + "\t" + restOfParagraph
        //Repalce the inputed paragraph in the textView, with the new paragraph
        textView.insertText(newParagraph, replacementRange: paragraphRange)
        //Style the newly inputed paragraph in the textView, to have a textList in its paragraphStyle attribute
        let rangeOfNewParagraph = NSRange(location: paragraphRange.location, length: newParagraph.utf16.count)
        let newParStyle = textListParStyle(start: listNumber)
        textView.textStorage?.addAttribute(.paragraphStyle, value: newParStyle, range: rangeOfNewParagraph)
        //Change typing attributes to include the new style holding the textList
        textView.typingAttributes[.paragraphStyle] = newParStyle
    }
    
    /**Given an index as an Int, return the substring from that index to end, as a string*/
    func subString(for str: String, from indexToStart: Int) -> String {
        let substring = str[str.index(str.startIndex, offsetBy: indexToStart)..<str.index(str.endIndex, offsetBy: 0)]
        return String(substring)
    }
    
    /**Given where the ordered list start from, builds a paragraph style holding a textList*/
    func textListParStyle(start: Int) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        //Build textList
        let textList = NSTextList(markerFormat: .decimal, options: 0)
        textList.startingItemNumber = start
        //Add
        paragraphStyle.textLists = [textList]
        return paragraphStyle
    }
    
}

