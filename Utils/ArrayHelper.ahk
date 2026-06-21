class ArrayHelper {
    /**
     * Sort an array of numbers in descending order.
     * Returns a new sorted array, leaving the original unchanged.
     * @param arr - Array of numeric values
     * @returns New array sorted in descending order
     */
    static SortDescending(arr) {
        sorted := arr.Clone()
        n := sorted.Length
        Loop n - 1 {
            i := A_Index + 1
            while (i > 1 && sorted[i] > sorted[i - 1]) {
                tmp := sorted[i]
                sorted[i] := sorted[i - 1]
                sorted[i - 1] := tmp
                i--
            }
        }
        return sorted
    }
}
