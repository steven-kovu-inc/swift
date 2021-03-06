//===--- ClosedRange.swift ------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// FIXME: swift-3-indexing-model: Generalize all tests to check both
// [Closed]Range.

/// An interval from a lower bound up to, and including, an upper bound.
///
/// You create a `ClosedRange` instance by using the closed range
/// operator (`...`).
///
///     let throughFive = 0...5
///
/// A `ClosedRange` instance contains both its lower bound and its
/// upper bound.
///
///     throughFive.contains(3)
///     // true
///     throughFive.contains(10)
///     // false
///     throughFive.contains(5)
///     // true
///
/// Because a closed range includes its upper bound, a closed range whose lower
/// bound is equal to the upper bound contains that value. Therefore, a
/// `ClosedRange` instance cannot represent an empty range.
///
///     let zeroInclusive = 0...0
///     zeroInclusive.contains(0)
///     // true
///     zeroInclusive.isEmpty
///     // false
///
/// Using a Closed Range as a Collection of Consecutive Values
/// ----------------------------------------------------------
///
/// When a closed range uses integers as its lower and upper bounds, or any
/// other type that conforms to the `Strideable` protocol with an integer
/// stride, you can use that range in a `for`-`in` loop or with any sequence or
/// collection method. The elements of the range are the consecutive values
/// from its lower bound up to, and including, its upper bound.
///
///     for n in 3...5 {
///         print(n)
///     }
///     // Prints "3"
///     // Prints "4"
///     // Prints "5"
///
/// Because floating-point types such as `Float` and `Double` are their own
/// `Stride` types, they cannot be used as the bounds of a countable range. If
/// you need to iterate over consecutive floating-point values, see the
/// `stride(from:through:by:)` function.
@_fixed_layout
public struct ClosedRange<Bound: Comparable> {
  /// The range's lower bound.
  public let lowerBound: Bound

  /// The range's upper bound.
  public let upperBound: Bound

  /// Creates an instance with the given bounds.
  ///
  /// Because this initializer does not perform any checks, it should be used
  /// as an optimization only when you are absolutely certain that `lower` is
  /// less than or equal to `upper`. Using the closed range operator (`...`)
  /// to form `ClosedRange` instances is preferred.
  ///
  /// - Parameter bounds: A tuple of the lower and upper bounds of the range.
  @_inlineable
  public init(uncheckedBounds bounds: (lower: Bound, upper: Bound)) {
    self.lowerBound = bounds.lower
    self.upperBound = bounds.upper
  }
}

// define isEmpty, which is available even on an uncountable ClosedRange
extension ClosedRange {
  /// A Boolean value indicating whether the range contains no elements.
  ///
  /// Because a closed range cannot represent an empty range, this property is
  /// always `false`.
  @_inlineable
  public var isEmpty: Bool {
    return false
  }
}

extension ClosedRange: RangeExpression {
  @_inlineable // FIXME(sil-serialize-all)
  public func relative<C: Collection>(to collection: C) -> Range<Bound>
  where C.Index == Bound {
    return Range(
      uncheckedBounds: (
        lower: lowerBound, upper: collection.index(after: self.upperBound)))
  }

  /// Returns a Boolean value indicating whether the given element is contained
  /// within the range.
  ///
  /// A `ClosedRange` instance contains both its lower and upper bound.
  /// `element` is contained in the range if it is between the two bounds or
  /// equal to either bound.
  ///
  /// - Parameter element: The element to check for containment.
  /// - Returns: `true` if `element` is contained in the range; otherwise,
  ///   `false`.
  @_inlineable
  public func contains(_ element: Bound) -> Bool {
    return element >= self.lowerBound && element <= self.upperBound
  }
}

extension ClosedRange: Sequence
where Bound: Strideable, Bound.Stride: SignedInteger {
  public typealias Element = Bound
  public typealias Iterator = IndexingIterator<ClosedRange<Bound>>
}

extension ClosedRange where Bound : Strideable, Bound.Stride : SignedInteger {
  public enum Index {
    case pastEnd
    case inRange(Bound)
  }
}

extension ClosedRange.Index : Comparable {
  @_inlineable
  public static func == (
    lhs: ClosedRange<Bound>.Index,
    rhs: ClosedRange<Bound>.Index
  ) -> Bool {
    switch (lhs, rhs) {
    case (.inRange(let l), .inRange(let r)):
      return l == r
    case (.pastEnd, .pastEnd):
      return true
    default:
      return false
    }
  }

  @_inlineable
  public static func < (
    lhs: ClosedRange<Bound>.Index,
    rhs: ClosedRange<Bound>.Index
  ) -> Bool {
    switch (lhs, rhs) {
    case (.inRange(let l), .inRange(let r)):
      return l < r
    case (.inRange(_), .pastEnd):
      return true
    default:
      return false
    }
  }
}

extension ClosedRange.Index: Hashable 
where Bound: Strideable, Bound.Stride: SignedInteger, Bound: Hashable {
  public var hashValue: Int {
    switch self {
    case .inRange(let value):
      return value.hashValue
    case .pastEnd:
      return .max
    }
  }
}

// FIXME: this should only be conformance to RandomAccessCollection but
// the compiler balks without all 3
extension ClosedRange: Collection, BidirectionalCollection, RandomAccessCollection
where Bound : Strideable, Bound.Stride : SignedInteger
{
  // while a ClosedRange can't be empty, a _slice_ of a ClosedRange can,
  // so ClosedRange can't be its own self-slice unlike Range
  public typealias SubSequence = Slice<ClosedRange<Bound>>

  /// The position of the first element in the range.
  @_inlineable
  public var startIndex: Index {
    return .inRange(lowerBound)
  }

  /// The range's "past the end" position---that is, the position one greater
  /// than the last valid subscript argument.
  @_inlineable
  public var endIndex: Index {
    return .pastEnd
  }

  @_inlineable
  public func index(after i: Index) -> Index {
    switch i {
    case .inRange(let x):
      return x == upperBound
        ? .pastEnd
        : .inRange(x.advanced(by: 1))
    case .pastEnd: 
      _preconditionFailure("Incrementing past end index")
    }
  }

  @_inlineable
  public func index(before i: Index) -> Index {
    switch i {
    case .inRange(let x):
      _precondition(x > lowerBound, "Incrementing past start index")
      return .inRange(x.advanced(by: -1))
    case .pastEnd: 
      _precondition(upperBound >= lowerBound, "Incrementing past start index")
      return .inRange(upperBound)
    }
  }

  @_inlineable
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    switch i {
    case .inRange(let x):
      let d = x.distance(to: upperBound)
      if n <= d {
        let newPosition = x.advanced(by: numericCast(n))
        _precondition(newPosition >= lowerBound,
          "Advancing past start index")
        return .inRange(newPosition)
      }
      if d - -1 == n { return .pastEnd }
      _preconditionFailure("Advancing past end index")
    case .pastEnd:
      if n == 0 {
        return i
      } 
      if n < 0 {
        return index(.inRange(upperBound), offsetBy: numericCast(n + 1))
      }
      _preconditionFailure("Advancing past end index")
    }
  }

  @_inlineable
  public func distance(from start: Index, to end: Index) -> Int {
    switch (start, end) {
    case let (.inRange(left), .inRange(right)):
      // in range <--> in range
      return numericCast(left.distance(to: right))
    case let (.inRange(left), .pastEnd):
      // in range --> end
      return numericCast(1 + left.distance(to: upperBound))
    case let (.pastEnd, .inRange(right)):
      // in range <-- end
      return numericCast(upperBound.distance(to: right) - 1)
    case (.pastEnd, .pastEnd):
      // end <--> end
      return 0
    }
  }

  /// Accesses the element at specified position.
  ///
  /// You can subscript a collection with any valid index other than the
  /// collection's end index. The end index refers to the position one past
  /// the last element of a collection, so it doesn't correspond with an
  /// element.
  ///
  /// - Parameter position: The position of the element to access. `position`
  ///   must be a valid index of the range, and must not equal the range's end
  ///   index.
  @_inlineable
  public subscript(position: Index) -> Bound {
    // FIXME: swift-3-indexing-model: range checks and tests.
    switch position {
    case .inRange(let x): return x
    case .pastEnd: _preconditionFailure("Index out of range")
    }
  }

  @_inlineable
  public subscript(bounds: Range<Index>)
    -> Slice<ClosedRange<Bound>> {
    return Slice(base: self, bounds: bounds)
  }

  @_inlineable
  public func _customContainsEquatableElement(_ element: Bound) -> Bool? {
    return lowerBound <= element && element <= upperBound
  }

  @_inlineable
  public func _customIndexOfEquatableElement(_ element: Bound) -> Index?? {
    return lowerBound <= element && element <= upperBound
              ? .inRange(element) : nil
  }
}

extension Comparable {  
  /// Returns a closed range that contains both of its bounds.
  ///
  /// Use the closed range operator (`...`) to create a closed range of any type
  /// that conforms to the `Comparable` protocol. This example creates a
  /// `ClosedRange<Character>` from "a" up to, and including, "z".
  ///
  ///     let lowercase = "a"..."z"
  ///     print(lowercase.contains("z"))
  ///     // Prints "true"
  ///
  /// - Parameters:
  ///   - minimum: The lower bound for the range.
  ///   - maximum: The upper bound for the range.
  @_inlineable // FIXME(sil-serialize-all)
  @_transparent
  public static func ... (minimum: Self, maximum: Self) -> ClosedRange<Self> {
    _precondition(
      minimum <= maximum, "Can't form Range with upperBound < lowerBound")
    return ClosedRange(uncheckedBounds: (lower: minimum, upper: maximum))
  }
}

extension Strideable where Stride: SignedInteger {  
  /// Returns a countable closed range that contains both of its bounds.
  ///
  /// Use the closed range operator (`...`) to create a closed range of any type
  /// that conforms to the `Strideable` protocol with an associated signed
  /// integer `Stride` type, such as any of the standard library's integer
  /// types. This example creates a `ClosedRange<Int>` from zero up to,
  /// and including, nine.
  ///
  ///     let singleDigits = 0...9
  ///     print(singleDigits.contains(9))
  ///     // Prints "true"
  ///
  /// You can use sequence or collection methods on the `singleDigits` range.
  ///
  ///     print(singleDigits.count)
  ///     // Prints "10"
  ///     print(singleDigits.last)
  ///     // Prints "9"
  ///
  /// - Parameters:)`.
  ///   - minimum: The lower bound for the range.
  ///   - maximum: The upper bound for the range.
  @_inlineable // FIXME(sil-serialize-all)
  @_transparent
  public static func ... (minimum: Self, maximum: Self) -> ClosedRange<Self> {
    // FIXME: swift-3-indexing-model: tests for traps.
    _precondition(
      minimum <= maximum, "Can't form Range with upperBound < lowerBound")
    return ClosedRange(uncheckedBounds: (lower: minimum, upper: maximum))
  }
}

extension ClosedRange: Equatable {
  /// Returns a Boolean value indicating whether two ranges are equal.
  ///
  /// Two ranges are equal when they have the same lower and upper bounds.
  ///
  ///     let x: ClosedRange = 5...15
  ///     print(x == 5...15)
  ///     // Prints "true"
  ///     print(x == 10...20)
  ///     // Prints "false"
  ///
  /// - Parameters:
  ///   - lhs: A range to compare.
  ///   - rhs: Another range to compare.
  @_inlineable
  public static func == (
    lhs: ClosedRange<Bound>, rhs: ClosedRange<Bound>
  ) -> Bool {
    return lhs.lowerBound == rhs.lowerBound && lhs.upperBound == rhs.upperBound
  }
}

extension ClosedRange : CustomStringConvertible {
  /// A textual representation of the range.
  @_inlineable // FIXME(sil-serialize-all)...\(
  public var description: String {
    return "\(lowerBound)...\(upperBound)"
  }
}

extension ClosedRange : CustomDebugStringConvertible {
  /// A textual representation of the range, suitable for debugging.
  @_inlineable // FIXME(sil-serialize-all)
  public var debugDescription: String {
    return "ClosedRange(\(String(reflecting: lowerBound))"
    + "...\(String(reflecting: upperBound)))"
  }
}

extension ClosedRange : CustomReflectable {
  @_inlineable // FIXME(sil-serialize-all)
  public var customMirror: Mirror {
    return Mirror(
      self, children: ["lowerBound": lowerBound, "upperBound": upperBound])
  }
}

extension ClosedRange {
  /// Returns a copy of this range clamped to the given limiting range.
  ///
  /// The bounds of the result are always limited to the bounds of `limits`.
  /// For example:
  ///
  ///     let x: ClosedRange = 0...20
  ///     print(x.clamped(to: 10...1000))
  ///     // Prints "10...20"
  ///
  /// If the two ranges do not overlap, the result is a single-element range at
  /// the upper or lower bound of `limits`.
  ///
  ///     let y: ClosedRange = 0...5
  ///     print(y.clamped(to: 10...1000))
  ///     // Prints "10...10"
  ///
  /// - Parameter limits: The range to clamp the bounds of this range.
  /// - Returns: A new range clamped to the bounds of `limits`.
  @_inlineable // FIXME(sil-serialize-all)
  @inline(__always)
  public func clamped(to limits: ClosedRange) -> ClosedRange {
    let lower =         
      limits.lowerBound > self.lowerBound ? limits.lowerBound
          : limits.upperBound < self.lowerBound ? limits.upperBound
          : self.lowerBound
    let upper =
      limits.upperBound < self.upperBound ? limits.upperBound
          : limits.lowerBound > self.upperBound ? limits.lowerBound
          : self.upperBound
    return ClosedRange(uncheckedBounds: (lower: lower, upper: upper))
  }
}

extension ClosedRange where Bound: Strideable, Bound.Stride : SignedInteger {
  /// Now that Range is conditionally a collection when Bound: Strideable,
  /// CountableRange is no longer needed. This is a deprecated initializer
  /// for any remaining uses of Range(countableRange).
  @available(*,deprecated: 4.2, 
    message: "CountableRange is now Range. No need to convert any more.")
  public init(_ other: ClosedRange<Bound>) {
    self = other
  }  
  
  /// Creates an instance equivalent to the given `Range`.
  ///
  /// - Parameter other: A `Range` to convert to a `ClosedRange` instance.
  ///
  /// An equivalent range must be representable as a closed range.
  /// For example, passing an empty range as `other` triggers a runtime error,
  /// because an empty range cannot be represented by a closed range instance.
  public init(_ other: Range<Bound>) {
    _precondition(!other.isEmpty, "Can't form an empty closed range")
    let upperBound = other.upperBound.advanced(by: -1)
    self.init(uncheckedBounds: (lower: other.lowerBound, upper: upperBound))
  }
}

extension ClosedRange {
  @_inlineable
  public func overlaps(_ other: ClosedRange<Bound>) -> Bool {
    return self.contains(other.lowerBound) || other.contains(lowerBound)
  }

  @_inlineable
  public func overlaps(_ other: Range<Bound>) -> Bool {
    return other.overlaps(self)
  }
}

@available(*, deprecated, renamed: "ClosedRange.Index")
public typealias ClosedRangeIndex<T> = ClosedRange<T>.Index where T: Strideable, T.Stride: SignedInteger
@available(*, deprecated, renamed: "ClosedRange")
public typealias CountableClosedRange<T: Comparable> = ClosedRange<T>
