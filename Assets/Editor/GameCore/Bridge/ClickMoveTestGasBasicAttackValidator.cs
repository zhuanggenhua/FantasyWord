#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;
using UnityEngine.EventSystems;

namespace FantasyWord.GameCore
{
    /// <summary>
    /// ClickMoveTest 的 EX-GAS 普攻 PlayMode 验证入口。
    /// 只验证 Ability 20001 经由 GAS Timeline / TaskApplyEffects / GameplayEffect 伤害训练假人。
    /// </summary>
    public static class ClickMoveTestGasBasicAttackValidator
    {
        private const int BasicAttackAbilityCode = 20001;
        private const int MaxStartupFrames = 120;
        private const int FramesBetweenAttacks = 90;
        private const int MaxAttackAttempts = 40;
        private static readonly Vector3 RuntimeAttackProbeOffset = new(-1.0f, -0.1f, 0.0f);
        private const float MinimumVisibleBodyCenterDistance = 0.7f;
        private const string ResultRelativePath = "Temp/UnityBridge/results/clickmove-gas-basic-attack-runtime.json";
        private const string DamageFrameScreenshotRelativePath =
            "Assets/Screenshots/GASBasicAttack/clickmove-gas-basic-attack-dmg-frame-validated.png";

        private static ValidationResult? s_result;
        private static CharacterBase? s_player;
        private static CharacterBase? s_target;
        private static int s_startedFrame;
        private static int s_lastAttackFrame;
        private static int s_attackAttempts;
        private static int s_healthDropCount;
        private static int s_previousTargetHealth;
        private static MonoBehaviour? s_playerAnimationController;
        private static MonoBehaviour? s_targetAnimationController;
        private static SpriteRenderer? s_playerBodySprite;
        private static SpriteRenderer? s_targetBodySprite;
        private static int s_initialFloatingTextCount;
        private static int s_lastActiveFloatingTextCount;
        private static bool s_damageFrameScreenshotCaptured;
        private static bool s_running;

        public static string ResultPath => Path.GetFullPath(ResultRelativePath);
        public static string DamageFrameScreenshotPath => Path.GetFullPath(DamageFrameScreenshotRelativePath);

        public static string Start()
        {
            if (!Application.isPlaying)
            {
                WriteResult(Fail("GAS 普攻验证只能在 PlayMode 下启动。"));
                return ResultPath;
            }

            s_result = new ValidationResult
            {
                ScenePath = UnityEngine.SceneManagement.SceneManager.GetActiveScene().path,
                StartFrame = Time.frameCount
            };
            s_player = null;
            s_target = null;
            s_startedFrame = Time.frameCount;
            s_lastAttackFrame = -FramesBetweenAttacks;
            s_attackAttempts = 0;
            s_healthDropCount = 0;
            s_previousTargetHealth = -1;
            s_playerAnimationController = null;
            s_targetAnimationController = null;
            s_playerBodySprite = null;
            s_targetBodySprite = null;
            s_initialFloatingTextCount = 0;
            s_lastActiveFloatingTextCount = 0;
            s_damageFrameScreenshotCaptured = false;
            s_running = true;

            EditorApplication.update -= Tick;
            EditorApplication.update += Tick;
            return ResultPath;
        }

        private static void Tick()
        {
            if (!s_running || s_result == null)
            {
                StopTicking();
                return;
            }

            if (!Application.isPlaying)
            {
                WriteResult(Fail("GAS 普攻验证过程中 PlayMode 已退出。"));
                StopTicking();
                return;
            }

            try
            {
                if (!TryResolveParticipants(s_result))
                {
                    if (Time.frameCount - s_startedFrame > MaxStartupFrames)
                    {
                        FinalizeResult(s_result, "等待场景角色初始化超时。");
                    }

                    return;
                }

                if (!s_result.Initialized)
                {
                    InitializeCombatSetup(s_result);
                    return;
                }

                ObserveHealthDrop(s_result);

                if (s_target == null || s_target.dead || s_target.GetCurrentHealth() <= 0)
                {
                    FinalizeResult(s_result, string.Empty);
                    return;
                }

                if (s_attackAttempts >= MaxAttackAttempts)
                {
                    FinalizeResult(s_result, "达到最大普攻次数后训练假人仍未死亡。");
                    return;
                }

                if (Time.frameCount - s_lastAttackFrame >= FramesBetweenAttacks)
                {
                    FireBasicAttack(s_result);
                }
            }
            catch (Exception exception)
            {
                WriteResult(Fail(exception.ToString()));
                StopTicking();
            }
        }

        private static bool TryResolveParticipants(ValidationResult result)
        {
            if (s_player == null)
            {
                if (GameManager.Exists() &&
                    GameManager.HasSystem<PlayerSystem>())
                {
                    s_player = GameManager.PlayerSystem.GetCurrentControlledCharacterOrPlayerInstance();
                }

                if (s_player == null)
                {
                    s_player = FindCharacter("玩家");
                }
            }

            if (s_target == null)
            {
                s_target = FindCharacter("训练假人");
            }

            result.PlayerName = s_player != null ? s_player.name : "null";
            result.TargetName = s_target != null ? s_target.name : "null";
            result.GameManagerExists = GameManager.Exists();
            result.HasPlayerSystem = result.GameManagerExists && GameManager.HasSystem<PlayerSystem>();
            return s_player != null && s_target != null;
        }

        private static void InitializeCombatSetup(ValidationResult result)
        {
            if (s_player == null || s_target == null)
            {
                return;
            }

            result.PlayerPositionBefore = Format(s_player.transform.position);
            result.TargetPositionBefore = Format(s_target.transform.position);
            result.PlayerHasBasicAttackBeforeEquip = s_player.HasFormalGasAbility(BasicAttackAbilityCode);
            result.PlayerEquipBasicAttackResult = s_player.TryEquipFormalGasAbilityCodeToSlot(BasicAttackAbilityCode, 0);
            result.PlayerHasBasicAttackAfterEquip = s_player.HasFormalGasAbility(BasicAttackAbilityCode);
            result.TargetHasGas = s_target.TryGetFormalAbilitySystem(out _);
            result.TargetHasHitboxLayer = HasAnyColliderOnLayer(s_target.gameObject, 7);
            result.InitialTargetHealth = s_target.GetCurrentHealth();
            result.InitialTargetMaxHealth = s_target.GetMaxHealth();
            result.CombatTextDisplayCount = CountMonoBehavioursByTypeName("CombatTextDisplay", activeOnly: false);
            result.ActiveCombatTextDisplayCount = CountMonoBehavioursByTypeName("CombatTextDisplay", activeOnly: true);
            result.FloatingTextPoolCount = CountMonoBehavioursByTypeName("FloatingTextPool", activeOnly: false);
            result.ActiveFloatingTextPoolCount = CountMonoBehavioursByTypeName("FloatingTextPool", activeOnly: true);
            CaptureEventSystemState(result);
            s_initialFloatingTextCount = CountMonoBehavioursByTypeName("FloatingText", activeOnly: false);
            result.InitialFloatingTextCount = s_initialFloatingTextCount;

            s_playerAnimationController = FindMonoBehaviourByTypeName(s_player.gameObject, "AnimationController");
            s_targetAnimationController = FindMonoBehaviourByTypeName(s_target.gameObject, "AnimationController");
            s_playerBodySprite = FindBodySpriteRenderer(s_player.gameObject);
            s_targetBodySprite = FindBodySpriteRenderer(s_target.gameObject);
            result.InitialPlayerAnimationKey = GetCurrentAnimationKey(s_playerAnimationController);
            result.InitialPlayerSpriteName = GetSpriteName(s_playerBodySprite);
            result.InitialTargetAnimationKey = GetCurrentAnimationKey(s_targetAnimationController);
            result.InitialTargetSpriteName = GetSpriteName(s_targetBodySprite);

            PlacePlayerInsideBasicAttackRange(result);
            CaptureCollisionAndVisualState(result, "after-placement");

            Vector2 direction = s_target.transform.position - s_player.transform.position;
            if (direction.sqrMagnitude > 0.0001f)
            {
                s_player.SetTargetDirection(direction.normalized);
                s_player.SetLookAtDirection(direction.normalized);
            }

            s_previousTargetHealth = result.InitialTargetHealth;
            result.Initialized = true;

            if (!result.PlayerHasBasicAttackAfterEquip)
            {
                FinalizeResult(result, "玩家运行态没有持有 EX-GAS 普攻 Ability 20001。");
                return;
            }

            if (!result.TargetHasGas)
            {
                FinalizeResult(result, "训练假人没有正式 GAS AbilitySystemComponent。");
                return;
            }

            if (!result.TargetHasHitboxLayer)
            {
                FinalizeResult(result, "训练假人没有可被普攻 TargetCatcher 命中的 Hitbox 层碰撞体。");
                return;
            }

            if (result.InitialTargetHealth <= 0 || result.InitialTargetMaxHealth <= 0)
            {
                FinalizeResult(result, $"训练假人生命异常：{result.InitialTargetHealth}/{result.InitialTargetMaxHealth}。");
            }
        }

        private static void PlacePlayerInsideBasicAttackRange(ValidationResult result)
        {
            if (s_player == null || s_target == null)
            {
                return;
            }

            Vector3 targetPosition = s_target.transform.position;
            Vector3 playerPosition = new(
                targetPosition.x + RuntimeAttackProbeOffset.x,
                targetPosition.y + RuntimeAttackProbeOffset.y,
                s_player.transform.position.z);
            s_player.transform.position = playerPosition;
            Physics2D.SyncTransforms();
            result.PlayerRuntimeProbePosition = Format(playerPosition);
            result.Trace.Add(
                $"frame={Time.frameCount}, runtimeProbePosition player={Format(playerPosition)}, target={Format(targetPosition)}");
        }

        private static void FireBasicAttack(ValidationResult result)
        {
            if (s_player == null || s_target == null)
            {
                return;
            }

            bool releasedBeforeFire = s_player.StopFireFormalGasAbility(BasicAttackAbilityCode);
            Vector2 direction = s_target.transform.position - s_player.transform.position;
            if (direction.sqrMagnitude > 0.0001f)
            {
                s_player.SetTargetDirection(direction.normalized);
                s_player.SetLookAtDirection(direction.normalized);
            }

            EAbilityFireCheckResult fireResult = s_player.FireFormalGasAbility(
                BasicAttackAbilityCode,
                GameCommandContext.Script(s_player, "clickmove-gas-basic-attack-validator"));
            ++s_attackAttempts;
            s_lastAttackFrame = Time.frameCount;
            result.FireAttempts = s_attackAttempts;
            result.LastReleaseBeforeFireResult = releasedBeforeFire;
            result.LastFireResult = fireResult.ToString();
            result.Trace.Add(
                $"frame={Time.frameCount}, releaseBeforeFire={releasedBeforeFire}, fire={fireResult}, targetHp={s_target.GetCurrentHealth()}");
        }

        private static void ObserveHealthDrop(ValidationResult result)
        {
            if (s_target == null)
            {
                return;
            }

            ObserveVisibleFeedback(result);

            int currentHealth = s_target.GetCurrentHealth();
            if (s_previousTargetHealth >= 0 && currentHealth < s_previousTargetHealth)
            {
                ++s_healthDropCount;
                result.HealthDropCount = s_healthDropCount;
                result.Trace.Add($"frame={Time.frameCount}, hpDrop={s_previousTargetHealth}->{currentHealth}");
            }

            s_previousTargetHealth = currentHealth;
            result.FinalTargetHealth = currentHealth;
            result.TargetDead = s_target.dead;
        }

        private static void ObserveVisibleFeedback(ValidationResult result)
        {
            string currentAnimationKey = GetCurrentAnimationKey(s_playerAnimationController);
            string currentSpriteName = GetSpriteName(s_playerBodySprite);
            string currentTargetAnimationKey = GetCurrentAnimationKey(s_targetAnimationController);
            string currentTargetSpriteName = GetSpriteName(s_targetBodySprite);
            int activeFloatingTextCount = CountMonoBehavioursByTypeName("FloatingText", activeOnly: true);
            s_lastActiveFloatingTextCount = activeFloatingTextCount;

            if (!result.PlayerAttackAnimationObserved &&
                string.Equals(currentAnimationKey, "Attack", StringComparison.Ordinal))
            {
                result.PlayerAttackAnimationObserved = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, visibleAttackAnimation anim={currentAnimationKey}, sprite={currentSpriteName}");
            }

            if (!result.PlayerAttackSpriteObserved &&
                currentSpriteName.IndexOf("Attack", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                result.PlayerAttackSpriteObserved = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, visibleAttackSprite sprite={currentSpriteName}");
            }

            if (!result.TargetDamageAnimationObserved &&
                string.Equals(currentTargetAnimationKey, "Dmg", StringComparison.Ordinal))
            {
                result.TargetDamageAnimationObserved = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, visibleTargetDamageAnimation anim={currentTargetAnimationKey}, sprite={currentTargetSpriteName}");
                CaptureDamageFrameScreenshot(result, currentAnimationKey, currentSpriteName, currentTargetAnimationKey, currentTargetSpriteName);
            }

            if (!result.TargetDamageSpriteObserved &&
                currentTargetSpriteName.IndexOf("Dmg", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                result.TargetDamageSpriteObserved = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, visibleTargetDamageSprite sprite={currentTargetSpriteName}");
                CaptureDamageFrameScreenshot(result, currentAnimationKey, currentSpriteName, currentTargetAnimationKey, currentTargetSpriteName);
            }

            if (!result.FloatingDamageTextObserved && activeFloatingTextCount > 0)
            {
                result.FloatingDamageTextObserved = true;
                result.Trace.Add(
                    $"frame={Time.frameCount}, floatingDamageText active={activeFloatingTextCount}");
            }
        }

        private static void CaptureDamageFrameScreenshot(
            ValidationResult result,
            string playerAnimationKey,
            string playerSpriteName,
            string targetAnimationKey,
            string targetSpriteName)
        {
            if (s_damageFrameScreenshotCaptured)
            {
                return;
            }

            s_damageFrameScreenshotCaptured = true;
            Directory.CreateDirectory(Path.GetDirectoryName(DamageFrameScreenshotPath)!);
            ScreenCapture.CaptureScreenshot(DamageFrameScreenshotRelativePath);
            result.DamageFrameScreenshotPath = DamageFrameScreenshotPath;
            result.DamageFrameScreenshotFrame = Time.frameCount;
            result.DamageFramePlayerAnimationKey = playerAnimationKey;
            result.DamageFramePlayerSpriteName = playerSpriteName;
            result.DamageFrameTargetAnimationKey = targetAnimationKey;
            result.DamageFrameTargetSpriteName = targetSpriteName;
            result.Trace.Add(
                $"frame={Time.frameCount}, damageFrameScreenshot path={DamageFrameScreenshotPath}, playerAnim={playerAnimationKey}, playerSprite={playerSpriteName}, targetAnim={targetAnimationKey}, targetSprite={targetSpriteName}");
        }

        private static CharacterBase? FindCharacter(string namePart)
        {
            CharacterActor[] actors = UnityEngine.Object.FindObjectsByType<CharacterActor>(
                FindObjectsInactive.Exclude,
                FindObjectsSortMode.InstanceID);
            foreach (CharacterActor actor in actors)
            {
                if (actor != null && actor.name.Contains(namePart, StringComparison.Ordinal))
                {
                    return actor;
                }
            }

            return null;
        }

        private static bool HasAnyColliderOnLayer(GameObject root, int layer)
        {
            foreach (Collider2D collider in root.GetComponentsInChildren<Collider2D>(true))
            {
                if (collider != null && collider.gameObject.layer == layer)
                {
                    return true;
                }
            }

            return false;
        }

        private static MonoBehaviour? FindMonoBehaviourByTypeName(GameObject root, string typeName)
        {
            foreach (MonoBehaviour behaviour in root.GetComponentsInChildren<MonoBehaviour>(true))
            {
                if (behaviour != null &&
                    string.Equals(behaviour.GetType().Name, typeName, StringComparison.Ordinal))
                {
                    return behaviour;
                }
            }

            return null;
        }

        private static SpriteRenderer? FindBodySpriteRenderer(GameObject root)
        {
            foreach (SpriteRenderer spriteRenderer in root.GetComponentsInChildren<SpriteRenderer>(true))
            {
                if (spriteRenderer != null &&
                    string.Equals(spriteRenderer.gameObject.name, "Body", StringComparison.Ordinal))
                {
                    return spriteRenderer;
                }
            }

            return root.GetComponentInChildren<SpriteRenderer>(true);
        }

        private static string GetCurrentAnimationKey(MonoBehaviour? animationController)
        {
            if (animationController == null)
            {
                return "null";
            }

            PropertyInfo? property = animationController
                .GetType()
                .GetProperty("CurrentAnimationKey", BindingFlags.Public | BindingFlags.Instance);
            object? value = property?.GetValue(animationController);
            return value?.ToString() ?? "null";
        }

        private static string GetSpriteName(SpriteRenderer? spriteRenderer)
        {
            return spriteRenderer != null && spriteRenderer.sprite != null
                ? spriteRenderer.sprite.name
                : "null";
        }

        private static int CountMonoBehavioursByTypeName(string typeName, bool activeOnly)
        {
            int count = 0;
            MonoBehaviour[] behaviours = UnityEngine.Object.FindObjectsByType<MonoBehaviour>(
                FindObjectsInactive.Include,
                FindObjectsSortMode.InstanceID);
            foreach (MonoBehaviour behaviour in behaviours)
            {
                if (behaviour != null &&
                    string.Equals(behaviour.GetType().Name, typeName, StringComparison.Ordinal) &&
                    (!activeOnly || behaviour.isActiveAndEnabled))
                {
                    ++count;
                }
            }

            return count;
        }

        private static void FinalizeResult(ValidationResult result, string failure)
        {
            result.Completed = true;
            result.EndFrame = Time.frameCount;
            result.FinalTargetHealth = s_target != null ? s_target.GetCurrentHealth() : result.FinalTargetHealth;
            result.TargetDead = s_target != null && s_target.dead;
            result.PlayerPositionAfter = s_player != null ? Format(s_player.transform.position) : "null";
            result.TargetPositionAfter = s_target != null ? Format(s_target.transform.position) : "null";
            result.FinalPlayerAnimationKey = GetCurrentAnimationKey(s_playerAnimationController);
            result.FinalPlayerSpriteName = GetSpriteName(s_playerBodySprite);
            result.FinalTargetAnimationKey = GetCurrentAnimationKey(s_targetAnimationController);
            result.FinalTargetSpriteName = GetSpriteName(s_targetBodySprite);
            result.FinalFloatingTextCount = CountMonoBehavioursByTypeName("FloatingText", activeOnly: false);
            result.ActiveFloatingTextCount = s_lastActiveFloatingTextCount;
            CaptureEventSystemState(result);
            CaptureCollisionAndVisualState(result, "final");

            List<string> failures = new();
            if (!string.IsNullOrWhiteSpace(failure))
            {
                failures.Add(failure);
            }

            Require(result.PlayerHasBasicAttackAfterEquip, "玩家没有持有或无法装备 EX-GAS 普攻 Ability 20001。", failures);
            Require(result.TargetHasGas, "训练假人不是正式 GAS 目标。", failures);
            Require(result.InitialTargetHealth > 0, "训练假人初始生命值必须大于 0。", failures);
            Require(result.HealthDropCount > 0, "Ability 20001 没有让训练假人发生生命下降。", failures);
            Require(result.ActiveCombatTextDisplayCount > 0, "ClickMoveTest 没有启用正式伤害数字入口 CombatTextDisplay。", failures);
            Require(result.ActiveFloatingTextPoolCount > 0, "ClickMoveTest 没有启用正式伤害数字对象池 FloatingTextPool。", failures);
            Require(result.EventSystemCount == 1, $"ClickMoveTest 运行时必须只有一个正式 EventSystem，当前数量：{result.EventSystemCount}。", failures);
            Require(result.PlayerAttackAnimationObserved || result.PlayerAttackSpriteObserved, "Ability 20001 没有产生可见攻击动作。", failures);
            Require(result.TargetDamageAnimationObserved || result.TargetDamageSpriteObserved, "Ability 20001 没有让训练假人产生可见受伤动作。", failures);
            Require(!string.IsNullOrWhiteSpace(result.DamageFrameScreenshotPath) && File.Exists(result.DamageFrameScreenshotPath),
                "Ability 20001 没有在训练假人受伤动作帧生成验收截图。", failures);
            Require(result.FloatingDamageTextObserved, "Ability 20001 扣血后没有出现可见伤害数字反馈。", failures);
            Require(result.TargetDead, "Ability 20001 没有在限定次数内击杀训练假人。", failures);
            Require(IsCharacterLayer(result.PlayerLayerAfterPlacement), "玩家运行时根对象没有在 Character 层，不能证明俯视角角色身体碰撞参与移动阻挡。", failures);
            Require(IsCharacterLayer(result.TargetLayerAfterPlacement), "训练假人运行时根对象没有在 Character 层，不能证明俯视角角色身体碰撞参与移动阻挡。", failures);
            Require(IsCharacterLayer(result.PlayerLayerFinal), "玩家验证结束时根对象没有保持在 Character 层。", failures);
            Require(IsCharacterLayer(result.TargetLayerFinal), "训练假人验证结束时根对象没有保持在 Character 层。", failures);
            Require(!string.Equals(result.PlayerBodyColliderAfterPlacement, "null", StringComparison.Ordinal), "玩家缺少正式非触发根身体碰撞体。", failures);
            Require(!string.Equals(result.TargetBodyColliderAfterPlacement, "null", StringComparison.Ordinal), "训练假人缺少正式非触发根身体碰撞体。", failures);
            Require(result.CollisionFilterIncludesCharacterLayer, "GameConfig 的移动碰撞过滤没有包含 Character 层，角色之间不会互相阻挡。", failures);
            Require(!result.RootBodyOverlapAfterPlacement, "玩家和训练假人的正式角色实体碰撞体在攻击验证起点仍然重叠。", failures);
            Require(!result.RootBodyOverlapFinal, "玩家和训练假人的正式角色实体碰撞体在验证结束时仍然重叠。", failures);
            Require(!result.VisibleBodyCentersTooCloseAfterPlacement, "玩家和训练假人的身体图像中心距离过近，截图仍会表现成明显穿身。", failures);
            Require(!result.VisibleBodyCentersTooCloseFinal, "玩家和训练假人的身体图像中心距离过近，验证结束时仍会表现成明显穿身。", failures);

            result.Success = failures.Count == 0;
            result.Failures = failures.ToArray();
            result.Message = result.Success
                ? "ClickMoveTest GAS 普攻验证通过：Ability 20001 通过正式 GAS 链路反复命中、显示攻击动作、训练假人受伤动作和伤害数字，并击杀训练假人；玩家与训练假人的正式实体碰撞和身体图像中心距离均未判定为重叠。"
                : string.Join(" | ", failures);
            WriteResult(result);
            StopTicking();
        }

        private static void CaptureEventSystemState(ValidationResult result)
        {
            EventSystem[] eventSystems = UnityEngine.Object.FindObjectsByType<EventSystem>(
                FindObjectsInactive.Include,
                FindObjectsSortMode.InstanceID);
            result.EventSystemCount = eventSystems.Length;

            string[] names = new string[eventSystems.Length];
            for (int i = 0; i < eventSystems.Length; i++)
            {
                EventSystem eventSystem = eventSystems[i];
                names[i] = eventSystem != null
                    ? $"{GetHierarchyPath(eventSystem.transform)} active={eventSystem.gameObject.activeInHierarchy} enabled={eventSystem.enabled}"
                    : "null";
            }

            result.EventSystemNames = names;
        }

        private static void CaptureCollisionAndVisualState(ValidationResult result, string phase)
        {
            if (s_player == null || s_target == null)
            {
                return;
            }

            Collider2D? playerBodyCollider = FindRootBodyCollider(s_player.gameObject);
            Collider2D? targetBodyCollider = FindRootBodyCollider(s_target.gameObject);
            int characterLayer = LayerMask.NameToLayer("Character");
            bool rootOverlap = playerBodyCollider != null &&
                               targetBodyCollider != null &&
                               playerBodyCollider.bounds.Intersects(targetBodyCollider.bounds);
            float actorDistance = Vector2.Distance(s_player.transform.position, s_target.transform.position);
            float visibleBodyCenterDistance = CalculateVisibleBodyCenterDistance(s_playerBodySprite, s_targetBodySprite);
            bool visibleBodyCentersTooClose = visibleBodyCenterDistance >= 0.0f &&
                                              visibleBodyCenterDistance < MinimumVisibleBodyCenterDistance;

            string playerLayer = FormatLayer(s_player.gameObject.layer);
            string targetLayer = FormatLayer(s_target.gameObject.layer);
            string playerCollider = FormatCollider(playerBodyCollider);
            string targetCollider = FormatCollider(targetBodyCollider);
            string playerBodyBounds = FormatBounds(s_playerBodySprite != null ? s_playerBodySprite.bounds : default);
            string targetBodyBounds = FormatBounds(s_targetBodySprite != null ? s_targetBodySprite.bounds : default);
            result.CharacterLayerIndex = characterLayer;
            result.CollisionFilterLayerMask = GameManager.Config != null
                ? GameManager.Config.collisionContactFilter.layerMask.value
                : 0;
            result.CollisionFilterIncludesCharacterLayer = characterLayer >= 0 &&
                (result.CollisionFilterLayerMask & (1 << characterLayer)) != 0;

            if (phase == "after-placement")
            {
                result.PlayerLayerAfterPlacement = playerLayer;
                result.TargetLayerAfterPlacement = targetLayer;
                result.PlayerBodyColliderAfterPlacement = playerCollider;
                result.TargetBodyColliderAfterPlacement = targetCollider;
                result.RootBodyOverlapAfterPlacement = rootOverlap;
                result.ActorDistanceAfterPlacement = actorDistance;
                result.VisibleBodyCenterDistanceAfterPlacement = visibleBodyCenterDistance;
                result.VisibleBodyCentersTooCloseAfterPlacement = visibleBodyCentersTooClose;
                result.PlayerBodyBoundsAfterPlacement = playerBodyBounds;
                result.TargetBodyBoundsAfterPlacement = targetBodyBounds;
            }
            else
            {
                result.PlayerLayerFinal = playerLayer;
                result.TargetLayerFinal = targetLayer;
                result.PlayerBodyColliderFinal = playerCollider;
                result.TargetBodyColliderFinal = targetCollider;
                result.RootBodyOverlapFinal = rootOverlap;
                result.ActorDistanceFinal = actorDistance;
                result.VisibleBodyCenterDistanceFinal = visibleBodyCenterDistance;
                result.VisibleBodyCentersTooCloseFinal = visibleBodyCentersTooClose;
                result.PlayerBodyBoundsFinal = playerBodyBounds;
                result.TargetBodyBoundsFinal = targetBodyBounds;
            }

            result.Trace.Add(
                $"frame={Time.frameCount}, collisionState phase={phase}, actorDistance={actorDistance:0.###}, rootOverlap={rootOverlap}, bodyCenterDistance={visibleBodyCenterDistance:0.###}, playerLayer={playerLayer}, targetLayer={targetLayer}, collisionMask={result.CollisionFilterLayerMask}, includesCharacter={result.CollisionFilterIncludesCharacterLayer}, playerCollider={playerCollider}, targetCollider={targetCollider}");
        }

        private static Collider2D? FindRootBodyCollider(GameObject root)
        {
            Collider2D? fallback = null;
            foreach (Collider2D collider in root.GetComponentsInChildren<Collider2D>(true))
            {
                if (collider == null || collider.isTrigger || collider.gameObject.layer == 7)
                {
                    continue;
                }

                if (collider.attachedRigidbody != null &&
                    collider.attachedRigidbody.gameObject == root)
                {
                    return collider;
                }

                fallback ??= collider;
            }

            return fallback;
        }

        private static float CalculateVisibleBodyCenterDistance(SpriteRenderer? playerBody, SpriteRenderer? targetBody)
        {
            if (playerBody == null || targetBody == null)
            {
                return -1.0f;
            }

            return Vector2.Distance(playerBody.bounds.center, targetBody.bounds.center);
        }

        private static string FormatLayer(int layer)
        {
            string layerName = LayerMask.LayerToName(layer);
            return string.IsNullOrEmpty(layerName) ? $"{layer}:<unnamed>" : $"{layer}:{layerName}";
        }

        private static bool IsCharacterLayer(string layerLabel)
        {
            return layerLabel.EndsWith(":Character", StringComparison.Ordinal);
        }

        private static string FormatCollider(Collider2D? collider)
        {
            if (collider == null)
            {
                return "null";
            }

            return $"{collider.GetType().Name}@{GetHierarchyPath(collider.transform)} layer={FormatLayer(collider.gameObject.layer)} trigger={collider.isTrigger} bounds={FormatBounds(collider.bounds)}";
        }

        private static string FormatBounds(Bounds bounds)
        {
            return $"center={Format(bounds.center)}, size={Format(bounds.size)}";
        }

        private static string GetHierarchyPath(Transform transform)
        {
            List<string> names = new();
            Transform? current = transform;
            while (current != null)
            {
                names.Add(current.name);
                current = current.parent;
            }

            names.Reverse();
            return string.Join("/", names);
        }

        private static ValidationResult Fail(string message)
        {
            return new ValidationResult
            {
                Completed = true,
                Success = false,
                Message = message,
                Failures = new[] { message }
            };
        }

        private static void WriteResult(ValidationResult result)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(ResultPath)!);
            File.WriteAllText(ResultPath, JsonUtility.ToJson(result, true));
        }

        private static void StopTicking()
        {
            s_running = false;
            EditorApplication.update -= Tick;
        }

        private static void Require(bool condition, string failure, List<string> failures)
        {
            if (!condition)
            {
                failures.Add(failure);
            }
        }

        private static string Format(Vector3 value) => $"({value.x:0.###}, {value.y:0.###}, {value.z:0.###})";

        [Serializable]
        public sealed class ValidationResult
        {
            public bool Completed;
            public bool Success;
            public string Message = string.Empty;
            public string ScenePath = string.Empty;
            public int StartFrame;
            public int EndFrame;
            public bool Initialized;
            public bool GameManagerExists;
            public bool HasPlayerSystem;
            public string PlayerName = string.Empty;
            public string TargetName = string.Empty;
            public string PlayerPositionBefore = string.Empty;
            public string TargetPositionBefore = string.Empty;
            public string PlayerPositionAfter = string.Empty;
            public string TargetPositionAfter = string.Empty;
            public string PlayerRuntimeProbePosition = string.Empty;
            public string PlayerLayerAfterPlacement = string.Empty;
            public string TargetLayerAfterPlacement = string.Empty;
            public string PlayerLayerFinal = string.Empty;
            public string TargetLayerFinal = string.Empty;
            public string PlayerBodyColliderAfterPlacement = string.Empty;
            public string TargetBodyColliderAfterPlacement = string.Empty;
            public string PlayerBodyColliderFinal = string.Empty;
            public string TargetBodyColliderFinal = string.Empty;
            public string PlayerBodyBoundsAfterPlacement = string.Empty;
            public string TargetBodyBoundsAfterPlacement = string.Empty;
            public string PlayerBodyBoundsFinal = string.Empty;
            public string TargetBodyBoundsFinal = string.Empty;
            public bool RootBodyOverlapAfterPlacement;
            public bool RootBodyOverlapFinal;
            public float ActorDistanceAfterPlacement;
            public float ActorDistanceFinal;
            public float VisibleBodyCenterDistanceAfterPlacement;
            public float VisibleBodyCenterDistanceFinal;
            public bool VisibleBodyCentersTooCloseAfterPlacement;
            public bool VisibleBodyCentersTooCloseFinal;
            public string InitialPlayerAnimationKey = string.Empty;
            public string FinalPlayerAnimationKey = string.Empty;
            public string InitialPlayerSpriteName = string.Empty;
            public string FinalPlayerSpriteName = string.Empty;
            public string InitialTargetAnimationKey = string.Empty;
            public string FinalTargetAnimationKey = string.Empty;
            public string InitialTargetSpriteName = string.Empty;
            public string FinalTargetSpriteName = string.Empty;
            public bool PlayerHasBasicAttackBeforeEquip;
            public bool PlayerEquipBasicAttackResult;
            public bool PlayerHasBasicAttackAfterEquip;
            public bool TargetHasGas;
            public bool TargetHasHitboxLayer;
            public int CombatTextDisplayCount;
            public int ActiveCombatTextDisplayCount;
            public int FloatingTextPoolCount;
            public int ActiveFloatingTextPoolCount;
            public int EventSystemCount;
            public string[] EventSystemNames = Array.Empty<string>();
            public int CharacterLayerIndex = -1;
            public int CollisionFilterLayerMask;
            public bool CollisionFilterIncludesCharacterLayer;
            public int InitialFloatingTextCount;
            public int FinalFloatingTextCount;
            public int ActiveFloatingTextCount;
            public bool PlayerAttackAnimationObserved;
            public bool PlayerAttackSpriteObserved;
            public bool TargetDamageAnimationObserved;
            public bool TargetDamageSpriteObserved;
            public bool FloatingDamageTextObserved;
            public string DamageFrameScreenshotPath = string.Empty;
            public int DamageFrameScreenshotFrame;
            public string DamageFramePlayerAnimationKey = string.Empty;
            public string DamageFramePlayerSpriteName = string.Empty;
            public string DamageFrameTargetAnimationKey = string.Empty;
            public string DamageFrameTargetSpriteName = string.Empty;
            public int InitialTargetHealth;
            public int InitialTargetMaxHealth;
            public int FinalTargetHealth;
            public bool TargetDead;
            public int FireAttempts;
            public bool LastReleaseBeforeFireResult;
            public string LastFireResult = string.Empty;
            public int HealthDropCount;
            public string[] Failures = Array.Empty<string>();
            public List<string> Trace = new();
        }
    }
}
