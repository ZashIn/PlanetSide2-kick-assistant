/*!
	Library: BinarySearch, version 1.0
		Binary search for a sorted list (half interval search), in O(log n).
	
	Author: Zash
	License: LGPL
*/

/*!
	Function: BinarySearch(sortedArray, pattern, column := 0, offset := 0, partial := true, skipEmpty := true)
		Binary search for a sorted list (half interval search), in O(log n).
		
		Parameters::
			sortedList - a sorted list
			pattern - a search pattern
			column - (Optional) for 2d arrays: column with the sorted entries
			offset - (Optional) an offset to start at (to exclude headers)
			partial - (Optional) find partial matches
			skipEmpty - (Optional) skip empty values
			
		Example:
			> arr := ["a", "ba1", "ba2", "c"]
			> for i, v in BinarySearch(arr, "ba")  ; or while ....Next(i, v)
			> 	...
		
		Returns:
			Enum[i, v] - index i in sortedArray, value v
*/
BinarySearch(sortedArray, pattern, column := 0, offset := 0, partial := true, skipEmpty := true) {
	return new BinarySearchClass(sortedArray, pattern, column, offset, partial, skipEmpty)
}

/*!
	Class: BinarySearchClass
		Binary search for a sorted list (half interval search), in O(log n).
		
		See function above.
*/
class BinarySearchClass {
	/*!
		Constructor: (sortedArray, pattern, column := 0, offset := 0, partial := true, skipEmpty := true)
		See function @BinarySearch
	*/
	__New(sortedArray, pattern, column := 0, offset := 0, partial := true, skipEmpty := true) {
		for k, v in ["sortedArray", "pattern", "column", "offset", "partial", "skipEmpty"]
			this[v] := %v%
		this.patternLen := StrLen(pattern)
		this.midMatchIndex := this.BinarySearch()
		this.firstMatchIndex := this.midMatchIndex ? this.FirstMatchBefore(this.midMatchIndex) : 0
		return this._NewEnum()
	}
	
	_NewEnum() {
		this.i := this.firstMatchIndex - 1
		return this
	}
	
	Next(ByRef k, ByRef v) {
		if (++this.i = 0)
			return false
		isMatch := this.IsMatch(this.GetEntry(this.i))
		if (isMatch) {
			k := this.i
			v := this.sortedArray[k]
			return true
		}
		return (isMatch = "") ? this.Next(k, v) : false  ; Skip empty
	}
	
	BinarySearch() {
		len := this.sortedArray.Length()
		if (!len || !this.patternLen)
			return 0
		l := 1 + this.offset
		r := len
		While (l <= r) {
			m := Floor((r + l) / 2)
			Loop {
				entry := this.GetEntry(m)
				isMatch := this.IsMatch(entry)
				if (isMatch)
					return m
				else if (isMatch = false)
					break
				else if (++m > r)   ; Skip empty
					return 0
			}
			if  (this.pattern < entry)
				r := m - 1  ; => search in first half
			else ; if (this.pattern > entry)
				l := m + 1  ; => search in second half
		}
		return 0
	}
	
	FirstMatchBefore(start) {
		i := start
		stop := this.sortedArray.MinIndex() + this.offset
		While (--i >= stop) {
			if (this.IsMatch(this.GetEntry(i)) = false)   ; Skip empty
				break
		}
		return i+1
	}
	
	; Helper
	GetEntry(index) {
		entry := this.sortedArray[index]
		return (this.column) ? entry[this.column] : entry  ; Search in given column
	}
	
	; Returns true on match, else false (0). If this.skipEmpty = true and entry = "", an empty string "" is returned.
	IsMatch(entry) {
		 if (entry = "" && this.skipEmpty)
			return ""
		return ((this.partial ? SubStr(entry, 1, this.patternLen) : entry) = this.pattern)
	}
}
