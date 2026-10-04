# Swift Design Patterns Guidelines

Reference Repository: [eleev/swift-design-patterns](https://github.com/eleev/swift-design-patterns)

## Scope
Apply these guidelines whenever designing, structuring, creating, or refactoring Swift applications, services, view models, or libraries.

## Core Rules

1. **Architecture & Navigation**:
   - For SwiftUI/AppKit/UIKit user interfaces, default to **MVVM-C (MVVM + Coordinator)** or **Clean Architecture (VIPER / Clean-Swift)** depending on screen/flow complexity.
   - Do not embed navigation logic or inter-screen routing directly inside Views or ViewModels; delegate flow transitions to a **Coordinator / Router**.

2. **Creational & Inversion of Control**:
   - Always apply **Dependency Injection** through initializers. Services, network clients, system drivers, and repositories must adhere to protocols rather than concrete classes.
   - Use **Factory Method** or **Abstract Factory** when instantiating polymorphic families of components.
   - Use **Builder** for complex multi-parameter object configurations or pipeline specifications.

3. **Structural Abstractions**:
   - Use the **Facade Pattern** to encapsulate complex subsystem operations into a simple, high-level client interface.
   - Use the **Adapter Pattern** to isolate low-level system commands, C APIs, POSIX calls, or third-party libraries behind Swift-idiomatic protocol boundaries.
   - Use **Composition over Inheritance**: combine protocols with extensions instead of subclass trees.

4. **Behavioral Patterns & Reactive State**:
   - Manage presentation and shared states with `@Observable`, `Combine`, or `AsyncStream` (**Observer / Pub-Sub Pattern**).
   - Use the **State Pattern** with Swift enums (with associated values) to represent finite state machines. Avoid multiple independent boolean flags that allow invalid states.
   - Use the **Command Pattern** to represent discrete tasks, actions, or operations that require queuing, logging, retries, or execution management.
   - Use the **Strategy Pattern** to swap out sorting, filtering, encoding, or parsing algorithms at runtime.

5. **Concurrency & Thread Safety**:
   - Apply Modern Swift Concurrency (`actor`, `async/await`, `TaskGroup`, `@MainActor`).
   - Implement concurrency design patterns appropriately:
     - **Barrier / Actor isolation** for critical shared mutable state.
     - **Balking** to guard stateful actions (e.g. ignoring duplicate refresh/start triggers if already active).
     - **Guarded Suspension** to suspend asynchronously until prerequisites are fulfilled.

6. **Idiomatic Swift & Code Quality**:
   - **Protocol-Oriented Programming (POP)** and Value Semantics: Prefer `struct` and `enum` for data and state; use `class` or `actor` when reference identity or mutable concurrency isolation is necessary.
   - Adhere strictly to **SOLID** and **GRASP** design principles.
   - **Design for Testability**: All dependencies must be injectable as test doubles (mocks/stubs/spies) without touching real hardware, network, or filesystem in unit tests.
