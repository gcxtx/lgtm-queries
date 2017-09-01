// Copyright 2017 Semmle Ltd.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

/**
 * Provides classes and predicates for integer guards.
 */

import java
private import SSA
private import DefUse
private import RangeUtils
private import RangeAnalysis

/** An expression that might have the value `i`. */
private Expr exprWithIntValue(int i) {
  result.(ConstantIntegerExpr).getIntValue() = i or
  result.(ParExpr).getExpr() = exprWithIntValue(i) or
  result.(ConditionalExpr).getTrueExpr() = exprWithIntValue(i) or
  result.(ConditionalExpr).getFalseExpr() = exprWithIntValue(i)
}

/**
 * An expression for which the predicate `integerGuard` is relevant.
 * This includes `RValue` and `MethodAccess`.
 */
class IntComparableExpr extends Expr {
  IntComparableExpr() {
    this instanceof RValue or this instanceof MethodAccess
  }

  /** An integer that is directly assigned to the expression in case of a variable; or zero. */
  int relevantInt() {
    exists(SsaExplicitUpdate ssa, SsaSourceVariable v |
      this = v.getAnAccess() and
      ssa.getSourceVariable() = v and
      ssa.getDefiningExpr().(VariableAssign).getSource() = exprWithIntValue(result)
    ) or
    result = 0
  }
}

/**
 * An expression that directly tests whether a given expression is equal to `k` or not.
 * The set of `k`s is restricted to those that are relevant for the expression or
 * have a direct comparison with the expression.
 *
 * If `result` evaluates to `branch`, then `e` is guaranteed to be equal to `k` if `is_k`
 * is true, and different from `k` if `is_k` is false.
 */
pragma[nomagic]
Expr integerGuard(IntComparableExpr e, boolean branch, int k, boolean is_k) {
  exists(EqualityTest eqtest, boolean polarity |
    eqtest = result and
    eqtest.hasOperands(e, any(ConstantIntegerExpr c | c.getIntValue() = k)) and
    polarity = eqtest.polarity() and
    (branch = true and is_k = polarity or branch = false and is_k = polarity.booleanNot())
  ) or
  exists(EqualityTest eqtest, int val, Expr c, boolean upper |
    k = e.relevantInt() and
    eqtest = result and
    eqtest.hasOperands(e, c) and
    bounded(c, any(ZeroBound zb), val, upper, _) and
    is_k = false and
    (upper = true and val < k or upper = false and val > k) and
    branch = eqtest.polarity()
  ) or
  exists(ComparisonExpr comp, Expr c, int val, boolean upper |
    k = e.relevantInt() and
    comp = result and
    comp.hasOperands(e, c) and
    bounded(c, any(ZeroBound zb), val, upper, _) and
    is_k = false
    |
    comp.getLesserOperand() = c and comp.isStrict() and branch = true and val >= k and upper = false or // k <= val <= c < e, so e != k
    comp.getLesserOperand() = c and comp.isStrict() and branch = false and val < k and upper = true or
    comp.getLesserOperand() = c and not comp.isStrict() and branch = true and val > k and upper = false or
    comp.getLesserOperand() = c and not comp.isStrict() and branch = false and val <= k and upper = true or
    comp.getGreaterOperand() = c and comp.isStrict() and branch = true and val <= k and upper = true or
    comp.getGreaterOperand() = c and comp.isStrict() and branch = false and val > k and upper = false or
    comp.getGreaterOperand() = c and not comp.isStrict() and branch = true and val < k and upper = true or
    comp.getGreaterOperand() = c and not comp.isStrict() and branch = false and val >= k and upper = false
  )
}

/**
 * A guard that splits the values of a variable into one range with an upper bound of `k-1`
 * and one with a lower bound of `k`.
 *
 * If `branch_with_lower_bound_k` is true then `result` is equivalent to `k <= x`
 * and if it is false then `result` is equivalent to `k > x`.
 */
Expr intBoundGuard(RValue x, boolean branch_with_lower_bound_k, int k) {
  exists(ComparisonExpr comp, ConstantIntegerExpr c, int val |
    comp = result and
    comp.hasOperands(x, c) and
    c.getIntValue() = val and
    x.getVariable().getType() instanceof IntegralType
    |
    comp.getLesserOperand().getProperExpr() = c and comp.isStrict() and branch_with_lower_bound_k = true and val + 1 = k or // c < x
    comp.getLesserOperand().getProperExpr() = c and not comp.isStrict() and branch_with_lower_bound_k = true and val = k or // c <= x
    comp.getGreaterOperand().getProperExpr() = c and comp.isStrict() and branch_with_lower_bound_k = false and val = k or // x < c
    comp.getGreaterOperand().getProperExpr() = c and not comp.isStrict() and branch_with_lower_bound_k = false and val + 1 = k // x <= c
  )
}
