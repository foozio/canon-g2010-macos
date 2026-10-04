---
name: swift-design-patterns
description: >-
  Use this skill whenever designing, architecting, structuring, or refactoring Swift applications, modules, or services.
  Adheres to the patterns, architectures, and principles in eleev/swift-design-patterns (https://github.com/eleev/swift-design-patterns).
---

# Swift Design Patterns & Architecture Skill

This skill enforces best-practice software design patterns for Swift applications based on [eleev/swift-design-patterns](https://github.com/eleev/swift-design-patterns).

## Design Workflow

When designing a Swift application, feature, or service, follow this 6-step checklist:

### Step 1: Architectural Selection
- **SwiftUI Apps**: Default to **MVVM-C (MVVM + Coordinator)**.
  - `View`: Declarative representation of state. Contains zero business logic and zero direct navigation routing.
  - `ViewModel`: `@Observable` class or actor managing presentation state, user action handling, and data transformation.
  - `Coordinator / Router`: Controls flow, sheet/window presentation, and screen transitions.
- **Complex Subsystems / CLI / Modular Engines**: Use **Clean Architecture / VIPER**:
  - Separate `Interactor` (domain use cases), `Presenter` (output formatting), `Entity` (core business entities), and `Boundary Protocols`.

### Step 2: Protocol & Abstraction Layer (POP & Structural Patterns)
- Define capabilities using protocols first (**Protocol-Oriented Programming**).
- Apply the **Facade Pattern** to present a unified interface for complex internal subsystems (e.g. print servers, hardware monitors, file parsers).
- Apply the **Adapter Pattern** to isolate platform C APIs, shell invocations, or foreign SDKs behind Swift protocols.
- Avoid class inheritance hierarchies; use protocol composition (`ProtocolA & ProtocolB`) and extensions with default implementations.

### Step 3: Creational Design & Dependency Injection
- Always implement **Dependency Injection (DI)** through initializers:
  ```swift
  public protocol PrintServerServiceProtocol: Sendable {
      func start() async throws
      func stop() async throws
  }

  public final class AppState {
      private let printServer: PrintServerServiceProtocol

      public init(printServer: PrintServerServiceProtocol = DefaultPrintServerService()) {
          self.printServer = printServer
      }
  }
  ```
- Use **Factory Method** or **Abstract Factory** when instantiating varied strategies or platforms.
- Use **Builder** for complex multi-stage configurations.

### Step 4: Behavioral & State Modeling
- **State Machine Pattern**: Model states with Swift `enum` and associated values:
  ```swift
  public enum ProcessState: Equatable, Sendable {
      case idle
      case running(pid: Int32, startedAt: Date)
      case failed(errorDescription: String)
  }
  ```
- **Command Pattern**: Encapsulate actions (such as CUPS queue operations, print jobs, repair routines) into command structs/classes to support queuing, retrying, and progress tracking.
- **Strategy Pattern**: Decouple algorithms (e.g., job scheduling, dithering, rasterization) into swappable protocol implementers.
- **Observer Pattern**: Leverage `@Observable`, `Combine`, or `AsyncStream` to publish state updates to observers cleanly without retaining cycles (use `[weak self]` when using closures or NotificationCenter).

### Step 5: Concurrency & Synchronization
- Prioritize Swift structured concurrency (`actor`, `async/await`, `TaskGroup`).
- Apply concurrency patterns:
  - **Barrier / Isolation**: Isolate mutable state inside `actor` instances.
  - **Balking**: Guard entry points if an action is already in flight (e.g., refreshing or initializing).
  - **Guarded Suspension**: Suspend via `await` until state conditions match.

### Step 6: Principles & Verification
- Verify **SOLID** & **GRASP** compliance:
  - Single Responsibility: Each class/struct does one thing well.
  - Low Coupling & High Cohesion.
- **Testability**: Provide mock / stub implementations conforming to all service protocols in `Tests/`.
