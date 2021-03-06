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
 * Provides classes and predicates for working with test classes and methods.
 */

import Type
import Member
import semmle.code.java.frameworks.JUnitAnnotations

/** The Java class `junit.framework.TestCase`. */
class TypeJUnitTestCase extends RefType {
  TypeJUnitTestCase() {
    this.hasQualifiedName("junit.framework", "TestCase")
  }
}

/** The Java interface `junit.framework.Test`. */
class TypeJUnitTest extends RefType {
  TypeJUnitTest() {
    this.hasQualifiedName("junit.framework", "Test")
  }
}

/** The Java class `junit.framework.TestSuite`. */
class TypeJUnitTestSuite extends RefType {
  TypeJUnitTestSuite() {
    this.hasQualifiedName("junit.framework", "TestSuite")
  }
}

/** A JUnit 3.8 test class. */
class JUnit38TestClass extends Class {
  JUnit38TestClass() {
    exists(TypeJUnitTestCase tc | this.hasSupertype+(tc))
  }
}

/** A JUnit 3.8 `tearDown` method. */
class TearDownMethod extends Method {
   TearDownMethod() {
      this.hasName("tearDown") and
      this.hasNoParameters() and
      this.getReturnType().hasName("void") and
      exists(Method m | m.getDeclaringType() instanceof TypeJUnitTestCase |
        this.overrides*(m)
      )
   }
}

/**
 * A class detected to be a test class, either because it is a JUnit test class
 * or because its name or the name of one of its super-types contains the substring "Test".
 */
class TestClass extends Class {
  TestClass() {
    this instanceof JUnit38TestClass or 
    this.getASupertype*().getSourceDeclaration().getName().matches("%Test%") 
  }
}

/**
 * A test method declared within a JUnit 3.8 test class.
 */
class JUnit3TestMethod extends Method {
  JUnit3TestMethod() {
    this.isPublic() and
    this.getDeclaringType() instanceof JUnit38TestClass and
    this.getName().matches("test%") and
    this.getReturnType().hasName("void")  and
    this.hasNoParameters()
  }
}

/**
 * A JUnit 3.8 test suite method.
 */
class JUnit3TestSuite extends Method {
  JUnit3TestSuite() {
    this.isPublic() and
    this.isStatic() and
    (
      this.getDeclaringType() instanceof JUnit38TestClass or
      this.getDeclaringType().getAnAncestor() instanceof TypeJUnitTestSuite
    ) and
    this.hasName("suite") and
    this.getReturnType() instanceof TypeJUnitTest and
    this.hasNoParameters()
  }
}


/**
 * A JUnit test method that is annotated with the `org.junit.Test` annotation.
 */
class JUnit4TestMethod extends Method {
  JUnit4TestMethod() {
    this.getAnAnnotation().getType().hasQualifiedName("org.junit", "Test")
  }
}

/**
 * A JUnit `@Ignore` annotation.
 */
class JUnitIgnoreAnnotation extends Annotation {
  JUnitIgnoreAnnotation() {
    getType().hasQualifiedName("org.junit", "Ignore")
  }
}

/**
 * A method which, directly or indirectly, is treated as ignored by JUnit due to a `@Ignore`
 * annotation.
 */
class JUnitIgnoredMethod extends Method {
  JUnitIgnoredMethod() {
    getAnAnnotation() instanceof JUnitIgnoreAnnotation or
    exists(Class c |
      c = this.getDeclaringType() |
      c.getAnAnnotation() instanceof JUnitIgnoreAnnotation
    )
  }
}

/**
 * An annotation in TestNG.
 */
class TestNGAnnotation extends Annotation {
  TestNGAnnotation() {
    getType().getPackage().hasName("org.testng.annotations")
  }
}

/**
 * An annotation of type `org.test.ng.annotations.Test`.
 */
class TestNGTestAnnotation extends TestNGAnnotation {
  TestNGTestAnnotation() {
    getType().hasName("Test")
  }
}

/**
 * A TestNG test method, annotated with the `org.testng.annotations.Test` annotation.
 */
class TestNGTestMethod extends Method {
  TestNGTestMethod() {
    this.getAnAnnotation() instanceof TestNGTestAnnotation
  }

  /**
   * Identify a possible `DataProvider` for this method, if the annotation includes a `dataProvider`
   * value.
   */
  TestNGDataProviderMethod getADataProvider() {
    exists(TestNGTestAnnotation testAnnotation |
      testAnnotation = getAnAnnotation() and
      // The data provider must have the same name as the referenced data provider
      result.getDataProviderName() = testAnnotation.getValue("dataProvider").(StringLiteral).getRepresentedString() |
      // Either the data provider should be on the current class, or a supertype
      getDeclaringType().getAnAncestor() = result.getDeclaringType() or
      // Or the data provider class should be declared
      result.getDeclaringType() = testAnnotation.getValue("dataProviderClass").(TypeLiteral).getTypeName().getType()
    )
  }
}

/**
 * Any method detected to be a test method of a common testing framework,
 * including JUnit and TestNG.
 */
class TestMethod extends Method {
  TestMethod() {
    this instanceof JUnit3TestMethod
    or this instanceof JUnit4TestMethod
    or this instanceof TestNGTestMethod
  }
}

/**
 * A TestNG annotation used to mark a method that runs "before".
 */
class TestNGBeforeAnnotation extends TestNGAnnotation {
  TestNGBeforeAnnotation() {
    getType().getName().matches("Before%")
  }
}

/**
 * A TestNG annotation used to mark a method that runs "after".
 */
class TestNGAfterAnnotation extends TestNGAnnotation {
  TestNGAfterAnnotation() {
    getType().getName().matches("After%")
  }
}

/**
 * An annotation of type `org.testng.annotations.DataProvider` which is applied to methods to mark
 * them as data provider methods for TestNG.
 */
class TestNGDataProviderAnnotation extends TestNGAnnotation {
  TestNGDataProviderAnnotation() {
    getType().hasName("DataProvider")
  }
}

/**
 * An annotation of type `org.testng.annotations.Factory` which is applied to methods to mark
 * them as factory methods for TestNG.
 */
class TestNGFactoryAnnotation extends TestNGAnnotation {
  TestNGFactoryAnnotation() {
    getType().hasName("Factory")
  }
}

/**
 * An annotation of type `org.testng.annotations.Listeners` which is applied to classes to define
 * which listeners apply to them.
 */
class TestNGListenersAnnotation extends TestNGAnnotation {
  TestNGListenersAnnotation() {
    getType().hasName("Listeners")
  }

  /**
   * Get a listener defined in this annotation.
   */
  TestNGListenerImpl getAListener() {
    result = getAValue("value").(TypeLiteral).getTypeName().getType()
  }
}

/**
 * A concrete implementation class of one or more of the TestNG listener interfaces.
 */
class TestNGListenerImpl extends Class {
  TestNGListenerImpl() {
    getAnAncestor().hasQualifiedName("org.testng", "ITestNGListener")
  }
}

/**
 * A method annotated with `org.testng.annotations.DataProvider` marking it as a data provider method
 * for TestNG.
 *
 * This data provider method can be referenced by "name", and used by the test framework to provide
 * an instance of a particular value when running a test method.
 */
class TestNGDataProviderMethod extends Method {
  TestNGDataProviderMethod() {
    getAnAnnotation() instanceof TestNGDataProviderAnnotation
  }

  /**
   * The name associated with this data provider.
   */
  string getDataProviderName() {
    result = getAnAnnotation().(TestNGDataProviderAnnotation).getValue("name").(StringLiteral).getRepresentedString()
  }
}

/**
 * A constructor or method annotated with `org.testng.annotations.Factory` marking it as a factory
 * for TestNG.
 *
 * This factory callable is used to generate instances of parameterized test classes.
 */
class TestNGFactoryCallable extends Callable {
  TestNGFactoryCallable() {
    getAnAnnotation() instanceof TestNGFactoryAnnotation
  }
}

/**
 * A class that will be run using the `org.junit.runners.Parameterized` JUnit runner.
 */
class ParameterizedJUnitTest extends Class {
  ParameterizedJUnitTest() {
    getAnAnnotation().(RunWithAnnotation).getRunner().(Class).hasQualifiedName("org.junit.runners", "Parameterized")
  }
}

/**
 * A `@Category` annotation on a class or method, that categorizes the annotated test.
 */
class JUnitCategoryAnnotation extends Annotation {
  JUnitCategoryAnnotation() {
    getType().hasQualifiedName("org.junit.experimental.categories", "Category")
  }

  /**
   * One of the categories that this test is categorized as.
   */
  Type getACategory() {
    exists(TypeLiteral literal, Expr value |
      value = getValue("value") and
      (
        literal = value or
        literal = value.(ArrayCreationExpr).getInit().getAnInit()
      ) |
      result = literal.getTypeName().getType()
    )
  }
}

/**
 * A test class that will be run with theories.
 */
class JUnitTheoryTest extends Class {
  JUnitTheoryTest() {
    getAnAnnotation().(RunWithAnnotation).getRunner().(Class).hasQualifiedName("org.junit.experimental.theories", "Theories")
  }
}
