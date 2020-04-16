/*!
	Library: BinarySearch, version 1.0
		Binary search for a sorted list (half interval search), in O(log n).
	
	Author: Zash
	License: LGPL
*/

/*!
	Function: BinarySearch(sortedArray, pattern, column := 0, offset := 0, partial := true)
		Binary search for a sorted list (half interval search), in O(log n).
		
		Parameters::
			sortedList - a sorted list
			pattern - a search pattern
			column - (Optional) for 2d arrays: column with the sorted entries
			offset - (Optional) an offset to start at (to exclude headers)
			partial - (Optional) find partial matches
			
		Example:
			> arr := ["a", "ba1", "ba2", "c"]
			> for i, v in BinarySearch(arr, "ba")  ; or while ....Next(i, v)
			> 	...
		
		Returns:
			Enum[i, v] - index i in sortedArray, value v
*/
BinarySearch(sortedArray, pattern, column := 0, offset := 0, partial := true) {
	return new BinarySearchClass(sortedArray, pattern, column, offset, partial)
}

/*!
	Class: BinarySearchClass
		Binary search for a sorted list (half interval search), in O(log n).
		
		See function above.
*/
class BinarySearchClass {
	/*!
		Constructor: (sortedArray, pattern, column := 0, offset := 0, partial := true)
		See function @BinarySearch
	*/
	__New(sortedArray, pattern, column := 0, offset := 0, partial := true) {
		this.sortedArray := sortedArray
		this.pattern := pattern
		this.patternLen := StrLen(pattern)
		this.column := column
		this.offset := offset
		this.partial := partial
		this.midMatchIndex := this.BinarySearch()
		this.firstMatchIndex := this.midMatchIndex ? this.FirstMatchBefore(this.midMatchIndex) : 0
		return this._NewEnum()
	}
	
	_NewEnum() {
		this.i := this.firstMatchIndex - 1
		return this
	}
	
	Next(ByRef k, ByRef v) {
		FileAppend, next`n, *
		if (++this.i = 0 || !this.IsMatch(this.GetEntry(this.i)))
			return false
		k := this.i
		v := this.sortedArray[k]
		return true
	}
	
	BinarySearch() {
		len := this.sortedArray.Length()
		if (!len || !this.patternLen)
			return 0
		l := 1 + this.offset
		r := len
		While (l <= r) {
			m := Floor((r + l) / 2)
			entry := this.GetEntry(m)
			if (this.IsMatch(entry))
				return m
			else if  (this.pattern < entry)
				r := m - 1  ; => search in first half
			else if (this.pattern > entry)
				l := m + 1  ; => search in second half
		}
		return 0
	}
	
	FirstMatchBefore(start) {
		i := start
		stop := this.sortedArray.MinIndex() + this.offset
		While (--i >= stop) {
			if (!this.IsMatch(this.GetEntry(i)))
				break
		}
		return i+1
	}
	
	; Helper
	GetEntry(index) {
		entry := this.sortedArray[index]
		return (this.column) ? entry[this.column] : entry  ; Search in given column
	}
	
	IsMatch(entry) {
		return ((this.partial ? SubStr(entry, 1, this.patternLen) : entry) = this.pattern)
	}
}