// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library SimpleAddressSet {
  struct AddressSet {
    address[] _values;
    mapping(address value => uint index) _positions;
  }

  function contains(AddressSet storage set, address value) public view returns (bool) {
    return set._positions[value] != 0;
  }

  function add(AddressSet storage set, address value) public returns (bool) {
    if (!contains(set, value)) {
      set._values.push(value);
      // The value is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      set._positions[value] = set._values.length;
      return true;
    } else {
      return false;
    }
  }

  function remove(AddressSet storage set, address value) public returns (bool) {
    // We cache the value's position to prevent multiple reads from the same storage slot
    uint256 position = set._positions[value];

    if (position != 0) {
      // Equivalent to contains(set, value)
      // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
      // the array, and then remove the last element (sometimes called as 'swap and pop').
      // This modifies the order of the array, as noted in {at}.

      uint256 valueIndex = position - 1;
      uint256 lastIndex = set._values.length - 1;

      if (valueIndex != lastIndex) {
        address lastValue = set._values[lastIndex];

        // Move the lastValue to the index where the value to delete is
        set._values[valueIndex] = lastValue;
        // Update the tracked position of the lastValue (that was just moved)
        set._positions[lastValue] = position;
      }

      // Delete the slot where the moved value was stored
      set._values.pop();

      // Delete the tracked position for the deleted slot
      delete set._positions[value];

      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Returns the value stored at position `index` in the set. O(1).
   *
   * Note that there are no guarantees on the ordering of values inside the
   * array, and it may change when more values are added or removed.
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function at(AddressSet storage set, uint256 index) public view returns (address) {
    return set._values[index];
  }

  /**
   * @dev Returns the number of values on the set. O(1).
   */
  function length(AddressSet storage set) public view returns (uint256) {
    return set._values.length;
  }
}
