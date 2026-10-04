# Swift App Design Guidelines

Whenever designing, architecting, structuring, or refactoring Swift applications or modules, strictly follow the patterns, architectures, and principles established in [eleev/swift-design-patterns](https://github.com/eleev/swift-design-patterns).

---

## 1. Architectural Patterns
Select the appropriate architecture based on application scope and complexity:
- **MVVM / MVVM-C (Model-View-ViewModel + Coordinator)**:
  - Standard for SwiftUI and AppKit/UIKit applications.
  - Decouple navigation and flow logic from Views and ViewModels into dedicated **Coordinators / Routers**.
  - Keep ViewModels focused on presentation state transformation and user intent forwarding.
- **Clean Architecture / VIPER / Clean-Swift**:
  - For complex enterprise domains or large modular apps.
  - Distinct separation of concerns: `View` (UI), `Interactor` (business logic / use cases), `Presenter` (formatting for display), `Entity` (core business models), and `Router` (navigation).
- **RIBs (Router, Interactor, Builder)**:
  - For deep nested state workflows, component tree scoping, and strict builder-driven dependency injection.

---

## 2. Creational Patterns & Dependency Injection
- **Dependency Injection (DI)**:
  - Use constructor (initializer) injection as the default.
  - Define dependencies as protocols rather than concrete types to ensure testability and mockability.
- **Factory Method & Abstract Factory**:
  - Centralize object creation when instantiation logic varies or depends on runtime configurations/environments.
- **Builder Pattern**:
  - Use for constructing complex configurations or immutable domain models step-by-step.
- **Singleton (Controlled)**:
  - Restrict instantiation only when modeling genuinely unique hardware or system resources.
  - Always back singletons by protocols to allow injection of test doubles.
- **Object Pool / Lazy Initialization**:
  - Use lazy properties (`lazy var`) for expensive resources.
  - Use object pools when acquiring and releasing finite resources (e.g., workers, buffers).

---

## 3. Structural Patterns
- **Adapter**:
  - Wrap platform-specific, legacy, or C-based APIs (e.g. POSIX, CUPS, IOKit) in idiomatic Swift protocols.
- **Facade**:
  - Provide unified, clean high-level interfaces over complex subsystems or multi-service pipelines.
- **Decorator / Composite**:
  - Enhance functionality compositionally without subclassing, utilizing Swift extensions and protocol composition (`&`).
- **Proxy**:
  - Use proxies for access control, lazy loading, logging, or remote service dispatch.

---

## 4. Behavioral Patterns
- **Observer / Pub-Sub**:
  - Use `@Observable` (Swift 5.9+ / macOS 14+), `Combine` (`CurrentValueSubject`, `PassthroughSubject`), or `AsyncStream` / `AsyncSequence` for event streams and state observation.
- **Command**:
  - Encapsulate user actions or pipeline operations into command objects for queueing, execution control, and undo/redo operations.
- **State Pattern**:
  - Model lifecycle and connection states as explicit Swift enums with state transitions, avoiding scattered boolean flags.
- **Strategy Pattern**:
  - Extract algorithms (formatting, filtering, parsing, scheduling) into swappable protocol implementations.
- **Chain of Responsibility**:
  - Pass requests along a chain of handlers (e.g., error handlers, request middleware, validation chains).
- **Memento**:
  - Capture and externalize an object's internal state for snapshotting or rollback without violating encapsulation.

---

## 5. Concurrency & Synchronization
- **Modern Swift Concurrency First**:
  - Utilize `actor`, `Task`, `TaskGroup`, `AsyncStream`, and `@MainActor` for thread safety and structured concurrency.
- **Concurrency Patterns from eleev/swift-design-patterns**:
  - **Barrier**: Synchronize read/write operations or isolate write phases.
  - **Balking**: Guard actions so they only execute when an object is in a valid state (e.g., early return if already executing).
  - **Guarded Suspension**: Suspend/await execution until preconditions are met without blocking thread pools.
  - **Scheduler / Thread Pool**: Manage work allocation to prevent thread starvation and priority inversion.

---

## 6. Swift Idiomatic Language Patterns
- **Protocol-Oriented Programming (POP)**:
  - Favor protocols and protocol extensions with default implementations over deep class inheritance hierarchies.
- **Value Semantics**:
  - Prefer `struct` and `enum` for data models and state representations; use `class` only for identity, reference lifetimes, or Objective-C interop.
- **Rich Pattern Matching**:
  - Leverage Swift's pattern matching: wildcard (`_`), value-binding (`if case let`, `guard case let`), enum cases with associated values, and tuple patterns.

---

## 7. Software Design Principles (SOLID & GRASP)
- **SOLID**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion.
- **GRASP**: High Cohesion, Low Coupling, Information Expert, Controller, Protected Variations.
- **Design for Testability**: Every service and coordinator must be verifiable via unit and integration tests using protocol mocks or spies.
