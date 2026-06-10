# Runtime Patterns

## Lifecycle

- Use `Awake` for local reference setup.
- Use `OnEnable` and `OnDisable` for event subscription and cleanup.
- Use `Start` for logic that depends on other objects already being initialized.
- Keep `Update` empty unless the object truly needs per-frame work.

## Input

- Prefer the new Input System when the project already uses it or when building new systems.
- Use action assets, generated wrappers, or `PlayerInput` patterns instead of raw polling where possible.
- Keep input collection separate from gameplay decision logic.
- For UI-heavy projects, ensure keyboard, mouse, touch, and gamepad navigation are all considered.

## Physics

- Read player intent in `Update`, apply physics work in `FixedUpdate` when needed.
- Avoid direct transform writes on physics-driven objects.
- Prefer non-alloc physics queries in hot paths.
- Cache buffers used by overlap or raycast queries.

## Animation

- Separate animation requests from animation implementation.
- Drive Animator state from explicit gameplay state, not scattered trigger calls.
- Keep animation parameter names centralized when the project uses many controllers.

## Async, Coroutines, And Jobs

- Prefer `UniTask` for new Unity runtime async flows when it is available in the project, especially resource loading, scene loading, UI waits, gameplay presentation chains, network requests, and test drivers.
- Use coroutines only for short, local, frame-based orchestration on the main thread when that is clearly simpler than a cancellable async flow.
- Avoid adding new long-lived `System.Threading.Tasks.Task` or bare coroutine workflows in gameplay code when a UniTask-based path is possible.
- Tie async work to object lifetime with cancellation tokens, such as `GetCancellationTokenOnDestroy()` or the Unity-version equivalent destroy token.
- Do not add bare `async void`; use UniTask event helpers such as `UniTask.Action` / `UniTask.UnityAction`, or call `.Forget()` deliberately with an observable error path.
- Use Jobs or DOTS only when the workload is large enough and thread-safe.
- Never call UnityEngine object APIs from worker threads.

## Hot Path Rules

- Avoid LINQ, string building, delegate churn, and temporary list creation in hot loops.
- Cache component lookups.
- Pool frequently spawned objects such as bullets, floating text, enemies, and VFX.
- Measure first when performance work is not obviously critical.

## Save And Config Data

- Keep save models versionable and separate from transient runtime state.
- Treat ScriptableObjects as defaults and authored content, not per-save mutable state.
- Prefer explicit migration logic for save schema changes.

## Testing

- Use Edit Mode tests for pure logic, serializers, and data transformations.
- Use Play Mode tests for scene integration, prefabs, and timing-sensitive behaviors.
- If no automated tests exist, still validate lifecycle and scene-entry behavior mentally and by targeted inspection.

## Common Runtime Risks

- Event subscriptions that are never removed
- Coroutines that survive longer than their owner
- Accessing destroyed Unity objects without null semantics awareness
- Physics logic split incorrectly across `Update` and `FixedUpdate`
- Gameplay code directly changing UI widgets or asset data
